#!/bin/bash

set -e

# sudo yum update -y  # this can be problematic
sudo yum update -y --security  # security udpates only

sudo yum install -y pssh git
sudo yum install -y ganglia ganglia-web ganglia-gmond ganglia-gmetad
sudo yum install -y xfsprogs
