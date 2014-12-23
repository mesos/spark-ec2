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

pushd "$(dirname "$0")" > /dev/null

# Build the AMIs and simultaneously pipe the output to a log
#+ and to an awk script that will filter in only the artifact IDs
#+ for further processing.

packer build ./spark-packer.json -machine-readable \
    | tee "build-spark-amis.log" \
        >(
            awk -F "," '{
                if (($3 == "artifact") && ($5 == "id")) {
                    print $0
                }
            }' > "spark-ami-artifact-ids.csv"
        )

ami_count=$(
    wc -l "spark-ami-artifact-ids.csv" \
    | awk -F " " '{ print $1 }'
)

echo ""
echo "Successfully registered the following $ami_count AMIs:"

awk -F "," '{
    split($2, builder_name, ":")
    split($6, artifact_ids, "\\%\\!\\(PACKER\\_COMMA\\)")
    
    spark_version=builder_name[2]
    virtualization_type=builder_name[5]
    
    for (i in artifact_ids) {
        split(artifact_ids[i], a, ":")
        
        region=a[1]
        ami_id=a[2]
        
        print " * " spark_version " > "  region " > " virtualization_type " > " ami_id
        
        # '\'' is just a convoluted way of passing a single quote to system()
        system("mkdir -p '\''../ami-list/" spark_version "/" region "'\''")
        system("echo '\''" ami_id "'\'' > '\''../ami-list/" spark_version "/" region "/" virtualization_type "'\''")
    }
}' "./spark-ami-artifact-ids.csv"

popd > /dev/null
