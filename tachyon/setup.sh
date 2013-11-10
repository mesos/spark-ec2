#!/bin/bash

/root/spark-ec2/copy-dir /root/tachyon

/root/tachyon/bin/format.sh

/root/tachyon/bin/start.sh all Mount