if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: Both AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be defined." >&2
    exit 1
fi

if [ ! $(command -v packer) ]; then
    echo "Error: You do not appear to have packer installed." >&2
    exit 1
fi

set -e
set -o pipefail

build_start_time="$(date +'%s')"

pushd "$(dirname "$0")" > /dev/null

# If jsmin is installed, use it to strip comments from the template.

if [ $(command -v jsmin) ]; then
    template='jsmin < "./spark-packer-template.json"'
else
    template='cat "./spark-packer-template.json"'
fi

# Build the AMIs and simultaneously pipe the output to a log
#+ and to an awk script that will filter in only the artifact IDs
#+ for further processing.

packer build <(eval "$template") -machine-readable \
    | tee "build-spark-amis.log" \
        >(
            awk -F "," '{
                if (($3 == "artifact") && ($5 == "id")) {
                    print $0
                }
            }' > "spark-ami-artifact-ids.csv"
        )

ami_count=$(
    awk -F "," '{
        split($6, artifact_ids, "\\%\\!\\(PACKER\\_COMMA\\)")
        
        for (i in artifact_ids) {
            print artifact_ids[i]
        }
    }' "./spark-ami-artifact-ids.csv" | wc -l | tr -d ' '
)

echo ""
echo "Successfully registered the following $ami_count AMIs:"

sort <(
awk -F "," '{
    split($2, builder_name, ":")
    split($6, artifact_ids, "\\%\\!\\(PACKER\\_COMMA\\)")
    
    spark_version=builder_name[2]
    virtualization_type=builder_name[5]
    
    for (i in artifact_ids) {
        split(artifact_ids[i], a, ":")
        
        region=a[1]
        ami_id=a[2]
        
        print " * " region " > " virtualization_type " > " ami_id
        
        # '\'' is just a convoluted way of passing a single quote to system()
        system("mkdir -p '\''../ami-list/" region "'\''")
        system("echo '\''" ami_id "'\'' > '\''../ami-list/" region "/" virtualization_type "'\''")
    }
}' "./spark-ami-artifact-ids.csv"
)

popd > /dev/null

build_end_time="$(date +'%s')"

diff_secs="$(($build_end_time-$build_start_time))"
build_mins="$(($diff_secs / 60))"
build_secs="$(($build_secs - $build_mins * 60))"

echo ""
echo "Build finished in: ${build_mins}m ${build_secs}s"

# Not portable to BSD / OS X.
# format='%Hh %Mm %Ss'
# echo "Build finished in: $(date -u -d@"$diff_secs" +"$format")"
