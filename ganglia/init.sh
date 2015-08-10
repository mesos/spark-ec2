#!/bin/bash

# NOTE: Remove all rrds which might be around from an earlier run
rm -rf /var/lib/ganglia/rrds/*
rm -rf /mnt/ganglia/rrds/*

# Make sure rrd storage directory has right permissions
mkdir -p /mnt/ganglia/rrds
chown -R nobody:nobody /mnt/ganglia/rrds

/root/spark-ec2/ganglia/check_packages.py

pssh --inline \
    --host "$SLAVES $OTHER_MASTER" \
    --user root \
    --extra-args "-t -t $SSH_OPTS" \
    --timeout 0 \
    "spark-ec2/ganglia/check_packages.py"

# Post-package installation : Symlink /var/lib/ganglia/rrds to /mnt/ganglia/rrds
rmdir /var/lib/ganglia/rrds
ln -s /mnt/ganglia/rrds /var/lib/ganglia/rrds
