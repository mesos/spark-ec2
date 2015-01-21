#!/bin/bash

set -e

sudo debuginfo-install -q -y kernel

# Both of these can be problematic.
# sudo yum update -y
# sudo yum update -y --security
