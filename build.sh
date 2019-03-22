#!/bin/bash

set -e

#############################################
usage ()
{
    echo " Docker build scripts for MPI, XIOS and NEMO"
    echo ""
    echo " USAGE: ./build.sh [COMMAND] [OPTIONS]"
    echo ""
    echo " Examples of [COMMAND] can be:"
    echo "      base: build the base image including mpich, hdf5, netcdf etc"
    echo "          ./build.sh base tag=eu.gcr.io/bobeas-hpc/nemo/base v=1"
    echo ""
    echo "      xios: build xios"
    echo "          ./swarm.sh scale size=30"
    echo ""
    echo "      reload: rebuild image and distribute to nodes"
    echo "          ./swarm.sh reload size=15"
    echo ""
    echo "      login: login to Docker container of MPI master node for interactive usage"
    echo "          ./swarm.sh login"
    echo ""
    echo "      exec: execute shell command at the MPI master node"
    echo "          ./swarm.sh exec [SHELL COMMAND]"
    echo ""
}

build_base ()
{
    docker build -t eu.gcr.io/bobeas-hpc/nemo/base:v2 base/
}

build_xios ()
{
    docker build --build-arg NEMO_CONFIG=INDIAN_OCEAN -t eu.gcr.io/bobeas-hpc/nemo/xios:v3 xios/
}

build_onbuild ()
{
    docker build --build-arg NEMO_CONFIG=INDIAN_OCEAN NEMO_USER=mpi \
        -t eu.gcr.io/bobeas-hpc/nemo/onbuild:v11 onbuild/ 
}

#############################################

while [ "$1" != "" ];
do
    PARAM=$(echo "$1" | awk -F= '{print $1}')
    VALUE=$(echo "$1" | awk -F= '{print $2}')

    case $PARAM in
        help)
            usage
            exit
            ;;

        base)
            build_base
            exit
            ;;

        xios)
            build_xios
            exit
            ;;

        onbuild)
            build_onbuild
            exit
            ;;

    esac
    shift
done
