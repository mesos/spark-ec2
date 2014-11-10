# Proposal: Automate generation of Apache Spark machine images

This is a proposal to automate the generation of Spark AMIs, as well as other types of machine images or container formats such as Docker.

## Goals
This initiative has a few goals:

1. **Speed up `spark-ec2` launch times.**
	
	This is the original motivation for looking into automating the generation of AMIs. It currently takes 8-10 minutes and up to launch a Spark cluster on EC2, even for a cluster as small as 2 `m3.medium` nodes.
	
	People want faster cluster launch times, and they hold us to the promise of ["launch a cluster in about 5 minutes"](http://spark.apache.org/docs/1.1.0/index.html).
	
	Note that this proposal addresses this issue only insomuch as it relates to improving the AMIs that `spark-ec2` uses. Other improvements to `spark-ec2` are not covered in this proposal.
	
2. **Reduce the burden of and margin for error in building Spark images.**

	We don't need to build Spark images often--perhaps once per release is sufficient. But when we do, we want that process to be as automated and error-free as possible.
	
	Also, being able to build easily and build often makes sure our build scripts never go stale.

3. **Enable easier exploration of work that relies on new machine image types or container formats (e.g. testing via Docker).**

	Once we have some infrastructure in place for automatically generating images of various types, it will be easier to explore new work that reles on these new image types.
	
	Perhaps the most valuable new work of this nature would be figuring out how to efficiently build and test Spark in parallel using Docker containers.

## Current process for generating Spark images

There is no formal process at the moment for creating Spark images. Currently, someone will just manually run [`create_image.sh`](https://github.com/mesos/spark-ec2/blob/f6773584dd71afc49f1225be48439653313c0341/create_image.sh) on a base Linux AMI and replicate it across AWS regions as required.

## Proposed process for generating Spark images

We propose using [Packer](https://packer.io/) to automate the generation of Spark images. The key features of Packer that make it attractive are:

1. You can create images of multiple types (e.g. AMI and Docker) in parallel from a common template.
2. Packer comes with built-in support for Amazon EC2, Google Compute Engine, and Docker, among others.

We would have to maintain:

* a single Packer template that defines what images we want to build (e.g. AMI, GCE, Docker)
* a collection of shell scripts that describes how to build the images we want (e.g. like the aforementioned `create_image.sh`).

From there, the process to generate images is as simple as running Packer. With a repeatable and automated process like this, a wider community of users will be able to contribute improvements to the Packer template and related shell scripts.

## Appendix 1: Potential improvements to spark-ec2 launch times

Using Packer to generate a new set of AMIs that have Spark pre-installed (alongside another set without Spark), we were able to improve `spark-ec2`'s launch times with no modifications to `spark-ec2` itself or to [`setup.sh`](https://github.com/mesos/spark-ec2/blob/f6773584dd71afc49f1225be48439653313c0341/setup.sh).

Here is a rough benchmark of `spark-ec2` launch times using the current set of AMIs, as well as launch times using new AMIs with the latest updates and Spark pre-installed. 

Both benchmarks were run by launching Spark 1.1.0 clusters on EC2 with 1 master and 1 slave, both instances being of type `m3.medium`. `setup.sh` was modified only to insert timing statements using the Bash built-in, `time`.

Using the new, "pre-baked" AMIs cut the launch time down **from almost 10 minutes to under 4 minutes**. Further work can probably reduce this launch time even further.

### Current AMIs (single run)

```
 >>>    211s - SSH wait time
 >>>      0s - Initial setup
 >>>     23s - Run setup-slave on master
 >>>      1s - Cluster SSH key approval
 >>>      0s - rsync spark-ec2 to rest of cluster
 >>>     10s - Run setup-slave on rest of cluster
 >>>     11s - scala init
 >>>     57s - spark init
 >>>      0s - shark init
 >>>     22s - ephemeral-hdfs init
 >>>     18s - persistent-hdfs init
 >>>      0s - spark-standalone init
 >>>      9s - tachyon init
 >>>     99s - ganglia init
 >>>      2s - Deploy templates and config
 >>>      4s - scala setup
 >>>     22s - spark setup
 >>>      2s - shark setup
 >>>      9s - ephemeral-hdfs setup
 >>>      7s - persistent-hdfs setup
 >>>     29s - spark-standalone setup
 >>>     10s - tachyon setup
 >>>      2s - ganglia setup
 >>>    563s - Total
```

### New AMIs

#### Latest OS updates and Ganglia pre-installed (best run of 4)

```
 >>>     74s - SSH wait time
 >>>      0s - Initial setup
 >>>      8s - Run setup-slave on master
 >>>      1s - Cluster SSH key approval
 >>>      0s - rsync spark-ec2 to rest of cluster
 >>>     14s - Run setup-slave on rest of cluster
 >>>     11s - scala init
 >>>     60s - spark init
 >>>      0s - shark init
 >>>     28s - ephemeral-hdfs init
 >>>     19s - persistent-hdfs init
 >>>      0s - spark-standalone init
 >>>      8s - tachyon init
 >>>      3s - ganglia init
 >>>      1s - Deploy templates and config
 >>>      4s - scala setup
 >>>     22s - spark setup
 >>>      2s - shark setup
 >>>     14s - ephemeral-hdfs setup
 >>>      6s - persistent-hdfs setup
 >>>     29s - spark-standalone setup
 >>>     10s - tachyon setup
 >>>      3s - ganglia setup
 >>>    325s - Total
 ```

#### Latest OS updates, Ganglia, and Spark 1.1.0 pre-installed (best run of 4)

```
 >>>     95s - SSH wait time
 >>>      0s - Initial setup
 >>>      9s - Run setup-slave on master
 >>>      0s - Cluster SSH key approval
 >>>      0s - rsync spark-ec2 to rest of cluster
 >>>     10s - Run setup-slave on rest of cluster
 >>>      0s - scala init
 >>>      0s - spark init
 >>>      0s - shark init
 >>>      0s - ephemeral-hdfs init
 >>>      0s - persistent-hdfs init
 >>>      0s - spark-standalone init
 >>>      0s - tachyon init
 >>>      0s - ganglia init
 >>>      1s - Deploy templates and config
 >>>      1s - scala setup
 >>>      2s - spark setup
 >>>      2s - shark setup
 >>>     43s - ephemeral-hdfs setup
 >>>      9s - persistent-hdfs setup
 >>>     29s - spark-standalone setup
 >>>     15s - tachyon setup
 >>>      4s - ganglia setup
 >>>    227s - Total
```
