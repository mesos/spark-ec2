#!/bin/bash

set -e

sudo debuginfo-install -q -y kernel

# Both of these can be problematic.
# sudo yum update -y
# sudo yum update -y --security

sudo yum install -y pssh git
sudo yum install -y ganglia ganglia-web ganglia-gmond ganglia-gmetad
sudo yum install -y xfsprogs

# Install GNU parallel.
pushd /tmp
PARALLEL_VERSION="20141122"
wget "http://ftpmirror.gnu.org/parallel/parallel-${PARALLEL_VERSION}.tar.bz2"
bzip2 -dc "parallel-${PARALLEL_VERSION}.tar.bz2" | tar xvf -
pushd "parallel-${PARALLEL_VERSION}"
./configure --prefix=/usr  # Amazon Linux root user doesn't have /usr/local on its $PATH
make
sudo make install
popd
rm -rf "./parallel-${PARALLEL_VERSION}*"
popd

# Suppress citation notice.
echo "will cite" | parallel --bibtex
