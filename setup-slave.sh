#!/bin/bash

# Disable Transparent Huge Pages (THP)
# THP can result in system thrashing (high sys usage) due to frequent defrags of memory.
# Most systems recommends turning THP off.
if [[ -e /sys/kernel/mm/transparent_hugepage/enabled ]]; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi

# Make sure we are in the spark-ec2 directory
pushd /root/spark-ec2 > /dev/null

source ec2-variables.sh

# Set hostname based on EC2 private DNS name, so that it is set correctly
# even if the instance is restarted with a different private DNS name
PRIVATE_DNS=`wget -q -O - http://169.254.169.254/latest/meta-data/local-hostname`
hostname $PRIVATE_DNS
echo $PRIVATE_DNS > /etc/hostname
HOSTNAME=$PRIVATE_DNS  # Fix the bash built-in hostname variable too

echo "checking/fixing resolution of hostname"
bash /root/spark-ec2/resolve-hostname.sh

# Work around for R3 or I2 instances without pre-formatted ext3 disks
instance_type=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null)

echo "Setting up slave on `hostname`... of type $instance_type"

# Format & mount using ext4, which has the best performance among ext3, ext4, and xfs based
# on our shuffle heavy benchmark
function to_ext4 {
  device=$1
  mount_point=$2
  trim_on=$3
  EXT4_MOUNT_OPTS="defaults,noatime,nodiratime"

  mkdir -p $mount_point
  
  if [[ trim_on == true ]]; then
    echo $device $mount_point ' ext4 defaults,noatime,nodiratime,discard 0 0' >> /etc/fstab
  fi

  mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 $device
  mount -o $EXT4_MOUNT_OPTS $device $mount_point
}

if [[ $instance_type == r3* || $instance_type == i2* || $instance_type == hi1* ]]; then
  # Format & mount using ext4, which has the best performance among ext3, ext4, and xfs based
  # on our shuffle heavy benchmark
  rm -rf /mnt*
  device_array=(/dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg /dev/sdh /dev/sdi)

  total=${#device_array[*]}
 
  # To turn TRIM support on, change the third argument to true
  for (( i=0; i<=$(( $total - 1 )); i++ ))
  do
      case "$i" in
        0) mount_index="" ;;
        *) mount_index=$((i + 1)) ;;
      esac
      to_ext4 ${device_array[$i]} /mnt$mount_index false
  done
fi

# Mount options to use for ext3 and xfs disks (the ephemeral disks
# are ext3, but we use xfs for EBS volumes to format them faster)
XFS_MOUNT_OPTS="defaults,noatime,nodiratime,allocsize=8m"

yum install -q -y xfsprogs

function setup_ebs_volume {
  device=$1
  mount_point=$2
  if [[ -e $device ]]; then
    # Check if device is already formatted
    if ! blkid $device; then
      mkdir $mount_point
      if mkfs.xfs -q $device; then
        mount -o $XFS_MOUNT_OPTS $device $mount_point
        chmod -R a+w $mount_point
      else
        # mkfs.xfs is not installed on this machine or has failed;
        # delete /vol so that the user doesn't think we successfully
        # mounted the EBS volume
        rmdir $mount_point
      fi
    else
      # EBS volume is already formatted. Mount it if its not mounted yet.
      if ! grep -qs '$mount_point' /proc/mounts; then
        mkdir $mount_point
        mount -o $XFS_MOUNT_OPTS $device $mount_point
        chmod -R a+w $mount_point
      fi
    fi
  fi
}

devices=(/dev/sds /dev/sdt /dev/sdu /dev/sdv /dev/sdw /dev/sdx /dev/sdy /dev/sdz)

# Format and mount EBS volume (/dev/sd[s, t, u, v, w, x, y, z] as /vol[x] if the device exists
total=${#devices[*]}
 
for (( i=0; i<=$(( $total - 1 )); i++ ))
do
    setup_ebs_volume ${devices[$i]} /vol$i
done

# Alias vol to vol3 for backward compatibility: the old spark-ec2 script supports only attaching
# one EBS volume at /dev/sdv.
if [[ -e /vol3 && ! -e /vol ]]; then
  ln -s /vol3 /vol
fi

# Make data dirs writable by non-root users, such as CDH's hadoop user
chmod -R a+w /mnt*

# Remove ~/.ssh/known_hosts because it gets polluted as you start/stop many
# clusters (new machines tend to come up under old hostnames)
rm -f /root/.ssh/known_hosts

# Create swap space on /mnt
/root/spark-ec2/create-swap.sh $SWAP_MB

# Allow memory to be over committed. Helps in pyspark where we fork
echo 1 > /proc/sys/vm/overcommit_memory

# Add github to known hosts to get git@github.com clone to work
# TODO(shivaram): Avoid duplicate entries ?
cat /root/spark-ec2/github.hostkey >> /root/.ssh/known_hosts

# Create /usr/bin/realpath which is used by R to find Java installations
# NOTE: /usr/bin/realpath is missing in CentOS AMIs. See
# http://superuser.com/questions/771104/usr-bin-realpath-not-found-in-centos-6-5
echo '#!/bin/bash' > /usr/bin/realpath
echo 'readlink -e "$@"' >> /usr/bin/realpath
chmod a+x /usr/bin/realpath

popd > /dev/null
