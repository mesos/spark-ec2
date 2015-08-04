#!/bin/bash

# NOTE: Remove all rrds which might be around from an earlier run
rm -rf /var/lib/ganglia/rrds/*
rm -rf /mnt/ganglia/rrds/*

# Make sure rrd storage directory has right permissions
mkdir -p /mnt/ganglia/rrds
chown -R nobody:nobody /mnt/ganglia/rrds

OLD_GANGLIA_PACKAGES="httpd* php* ganglia* ganglia* ganglia-gmond* ganglia-gmetad*"
GANGLIA_PACKAGES="httpd24-2.4* php56-5.6* ganglia-3.6* ganglia-web-3.5* ganglia-gmond-3.6* ganglia-gmetad-3.6*"

#Uninstalls older version of ganglia from master if it was reinstalled in AMI
yum remove -q -y $OLD_GANGLIA_PACKAGES 2>&1 | grep -v "No Match for argument:"
yum install -q -y $GANGLIA_PACKAGES & sleep 1
wait

for node in $SLAVES $OTHER_MASTERS; do
  #Uninstalls older version of ganglia from other masters if it was reinstalled in AMI
  ssh -t -t $SSH_OPTS root@$node "yum remove -q -y $OLD_GANGLIA_PACKAGES  2>&1  | grep -v 'No Match for argument:'"
  ssh -t -t $SSH_OPTS root@$node "yum install -q -y $GANGLIA_PACKAGES" & sleep 0.3
done
wait

# Post-package installation : Symlink /var/lib/ganglia/rrds to /mnt/ganglia/rrds
rmdir /var/lib/ganglia/rrds
ln -s /mnt/ganglia/rrds /var/lib/ganglia/rrds
