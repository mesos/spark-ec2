import sys
import boto.ec2
import argparse

arg_parser = argparse.ArgumentParser(
    description="A tool to deregister unwanted AMIs and their associated snapshots."
)

arg_parser.add_argument(
    '--really',
    action='store_true',
    help="really deregister those AMIs"
)

arg_parser.add_argument(
    '--except-for',
    help="file containing newline-delimited list of AMIs to keep"
)

args = arg_parser.parse_args()

if not args.really:
    print "You don't really want to run this script, do you?"
    print "Re-run with --really to really do this."
    sys.exit()

if args.except_for:
    with open(args.except_for) as f:
        except_amis = [ami for ami in f.read().split('\n') if ami != '']
else:
    except_amis = []

ec2_regions = [
    region.name for region in boto.ec2.regions() 
    if region.name not in ['cn-north-1', 'us-gov-west-1']
]

for region in ec2_regions:
    print "Deregistering images in '{r}' region and deleting associated snapshots.".format(r=region)
    
    conn = boto.ec2.connect_to_region(region)
    images = conn.get_all_images(owners=['self'])
    
    if len(images) == 0:
        print " -> No images found in '{r}' region.".format(r=region)
        continue
    else:
        for image in images:
            if image.id not in except_amis:
                conn.deregister_image(image_id=image.id, delete_snapshot=True)
                print " -> Deregistered {ami}.".format(ami=image.id)

# for region in ec2_regions:
#     print "Deleting snapshots from '{r}' region.".format(r=region)
    
#     conn = boto.ec2.connect_to_region(region)
#     snapshots = conn.get_all_snapshots(owner='self')
    
#     for snapshot in snapshots:
#         conn.delete_snapshot(snapshot_id=snapshot.id)

#     print " -> Deleted {c} snapshots.".format(c=len(snapshots))
