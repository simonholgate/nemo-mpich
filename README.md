# README for nemo-mpich
## Simon Holgate <hello@simonholgate.org.uk>

This repository is based upon origin work by Pierre DERIAN 
<contact@pierrederian.net> (https://github.com/pderian/NEMOGCM-Docker)
and Nikyle Nguyen <simonholgate@MSN.com> 
(https://github.com/simonholgate/nemo-mpich) 

### Purpose: 
Docker container based on Debian Jessie image with [MPICH](http://www.mpich.org/) -- portable implementation of Message Passing Interface (MPI) standard -- to compile and run the NEMO ocean engine with parallel processing.

Provides solution for MPI Cluster Automation with Docker containers using either Docker Compose or Docker Swarm Mode running on Google Cloud.

### Requirements: docker, docker-machine, docker-compose 

With this framework, the NEMO and XIOS source files are moved from the docker volume to an NFS file server after the model is compiled.

The NFS file server is only required when running in swarm mode acros muliple machines that need to access the same file system.

Run files (e.g. file_def_nemo.xml) can be edited there using the usual tools (IDE, etc.). 

The NFS system is mounted by the containers so that input and output simulation files are also synchronized between the host and the container.

The container is only used to (i) compile and (ii) run the NEMO engine. Editing of configuration files and code modifications are best performed on the host and pushed to a repository that the container can pull from during the build process.

Tested successfully on Google Cloud running Debian Stretch and Debian Jessie
with Docker version 18.09.1, build 4c52b90.

References:
[1] http://forge.ipsl.jussieu.fr/nemo/wiki/Users
[2] http://forge.ipsl.jussieu.fr/nemo/wiki/Users/ModelInterfacing/InputsOutputs#ExtractingandinstallingXIOS
[3] http://forge.ipsl.jussieu.fr/nemo/wiki/Users/ModelInstall

----

Image usage instruction:
[https://eu.gcr.io/bobeas-hpc/nemo/xios](https://eu.gcr.ioi/bobeas-hpc/nemo/xios)


Distributed MPI cluster setup instruction: [https://github.com/simonholgate/nemo-mpich/tree/master/cluster](https://github.com/simonholgate/nemo-mpich/tree/master/cluster)

`base image` ([Dockerfile](https://github.com/simonholgate/nemo-mpich/blob/master/base/Dockerfile)) : contains MPICH, HDF5, NetCDF, parallel NetCDF, NetCDF Fortran and essential build tools. Intended to be used as development environment for developing MPI programs.

`xios image` ([Dockerfile](https://github.com/simonholgate/nemo-mpich/blob/master/xios/Dockerfile)) : inherits base image and contains XIOS 2.5 and NEMO 4 configured for the Indian Ocean. 

`onbuild image` ([Dockerfile](https://github.com/simonholgate/nemo-mpich/blob/onbuild/Dockerfile)) : inherits xios image with network setup for cluster. Contains configuration files for sshd etc and intended to be used to build image that contains compiled MPI program in order to deploy to a cluster.

`cluster` ([project scaffolder](https://github.com/simonholgate/nemo-mpich/tree/master/cluster)) : is a directory containing a setup for deploying MPI programs to a cluster of containers. Include a runner script to automate Docker commands.


*Below is instruction for building the Docker image yourself if you don't want to use the pre-built base or onbuild image.*

----

## Build Instruction

The images are prebuilt and hosted in Google Container Registry at eu.gcr.io, but in case you want to build
them yourself:

```sh
$ git clone https://github.com/simonholgate/nemo-mpich

$ cd nemo-mpich

$ docker build -t eu.gcr.io/bobeas-hpc/nemo/base base/

$ docker build -t eu.gcr.io/bobeas-hpc/nemo/xios xios/

$ docker build -t eu.gcr.io/bobeas-hpc/nemo/onbuild onbuild/
```

Since the onbuild image inherits the base image, if you use a different tag name (`eu.gcr.io/nemo`), you must change the first line in `xios/Dockerfile` and `onbuild/Dockerfile` to inherits `FROM` your custom tag name.

----


