# Spark Packer Scripts

These scripts use [Packer](http://www.packer.io/) to create and register a set of AMIs that include all the software we need to quickly launch Spark clusters on EC2.

These scripts create and register AMIs across the various axes of interest like AMI virtualization type and EC2 region, and on completion they update the AMI IDs in `ami-list/` automatically.

They use the [latest US East, EBS-backed Amazon Linux AMIs](http://aws.amazon.com/amazon-linux-ami/) as a base. The generated AMIs will be registered under the Amazon account associated with the AWS credentials set in the OS's environment.

In the near future, these scripts will be extended to support generating Spark images on other platforms like Docker and GCE.

## Usage

Just call this script:

```
./build_spark_amis.sh
```

Note that you can call this script from any working directory and it will work.

## Generated AMIs

Using Packer, these scripts create one EBS-backed AMI for every combination of the following attributes in parallel, for a total of 32 AMIs (2 × 2 × 8). Instance store AMIs are currently not covered.

### Base vs. Spark Pre-Installed

1. Base AMI
  * OS security patches
  * Python 2.7
  * Ganglia
  * Useful tools like `pssh`
2. Version-specific Spark AMI
  * Base AMI + a specific version of Spark and Hadoop installed

### AMI Virtualization Type

1. Hardware Virtual Machine (HVM)
2. Paravirtual (PV)

### EC2 Region

All [supported EC2 regions](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) which, as of Fall 2014, are:

1. `ap-northeast-1`
2. `ap-southeast-1`
3. `ap-southeast-2`
5. `eu-west-1`
6. `sa-east-1`
7. `us-east-1`
8. `us-west-1`
9. `us-west-2`

We currently don't support the `cn-north-1` or `eu-central-1` regions, as they require separate AWS credentials. (Note: This is definitely true for China; not sure about EU Central.)

# Prerequisites

[Download](http://www.packer.io/downloads.html) and install Packer to use the scripts here.
