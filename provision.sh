#!/bin/bash

# Script to provision multiple VMs for Docker Swarm
# Assumes we are on a Google Cloud VM so no credentials are required
PROJECT_ID=bobeas-hpc
GPC_ZONE=europe-west2-c
GPC_MACHINE=n1-standard-96
GPC_MACHINE_MANAGER=n1-standard-96
GPC_DISK=10
GPC_USER=root

NUM_WORKERS=4
NUM_SWARM=4

##########################
### Parse command line ###
##########################

while [ "$1" != "" ]; do
    case $1 in
        -p | --provider )       shift
                                PROVIDER=$1
                                ;;
        -i | --projectid )      shift
                                PROJECT_ID=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

#################
### Functions ###
#################

make_worker() {

## Function to make a worker. Takes a single arument which is a number to append to the
## worker name.

  docker-machine create --driver google \
    --google-project ${PROJECT_ID} \
    --google-zone ${GPC_ZONE} \
    --google-machine-type ${GPC_MACHINE} \
    --google-disk-size ${GPC_DISK} \
    --google-username ${GPC_USER} \
    worker${1}

## Add NFS 
  docker-machine ssh worker${1} 'apt-get update && apt-get install -y nfs-common'

## Upgrade
  docker-machine ssh worker${1} 'unattended-upgrade'

## Login to the container repository with key
  cat bobeas-hpc.json | docker-machine ssh worker${i} \
      "cat | docker login -u _json_key --password-stdin https://eu.gcr.io"

## Join swarm on workers
  docker-machine ssh worker${1} "docker swarm join --token \
    ${MANAGER_TOKEN} ${MANAGER_IP}:2377"

## Make NFS mount point on each machine and mount NFS
  docker-machine ssh worker${1} "mkdir -p /mnt/data && mount 10.193.200.114:/vol1 /mnt/data"

}


#*****************************#
### Provision manager first ###
#*****************************#

docker-machine create --driver google \
  --google-project ${PROJECT_ID} \
  --google-zone ${GPC_ZONE} \
  --google-machine-type ${GPC_MACHINE_MANAGER} \
  --google-disk-size ${GPC_DISK} \
  --google-username ${GPC_USER} \
  manager1

## Add NFS 
docker-machine ssh manager1 'apt-get update && apt-get install -y nfs-common'

## Upgrade
docker-machine ssh manager1 'unattended-upgrade'

## Login to the container repository with key
cat bobeas-hpc.json | docker-machine ssh manager1 \
    "cat | docker login -u _json_key --password-stdin https://eu.gcr.io"
 
## Install docker compose
docker-machine ssh manager1 \
'curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)"\
 -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose'

## Init swarm on manager1
docker-machine ssh manager1 'MGR_IP_ADDR=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip` && docker swarm init --advertise-addr ${MGR_IP_ADDR}'

## Make NFS mount point on each machine and mount NFS
docker-machine ssh manager1 "mkdir -p /mnt/data && mount 10.193.200.114:/vol1 /mnt/data"

## Clone git repo
docker-machine ssh manager1 'git clone https://github.com/simonholgate/alpine-mpich.git'

## Checkout branch
docker-machine ssh manager1 'cd alpine-mpich && git checkout crisc-bobeas-container && git pull'

## Fix ssh key permissions
docker-machine ssh manager1 'chmod 0600 alpine-mpich/cluster/ssh/id_rsa*' 

## Add firewall rules to open the required ports - will fail if already defined do delete it first
# https://gist.github.com/BretFisher/7233b7ecf14bc49eb47715bbeb2a2769
gcloud compute firewall-rules delete swarm-machines --quiet
gcloud compute firewall-rules create swarm-machines \
     --allow "tcp:22,tcp:2377,tcp:7946,tcp:10000-11000,udp:10000-11000,udp:4789,udp:7946,50" \
     --source-ranges 0.0.0.0/0 \
     --target-tags docker-machine \
     --project ${PROJECT_ID} \
     --quiet


#*****************************#
###   Provision workers     ###
#*****************************#

MANAGER_TOKEN=`docker-machine ssh manager1 "docker swarm join-token manager -q"`
MANAGER_IP=`docker-machine ip manager1`

for (( i=1 ; i<=${NUM_WORKERS}; i++ ));
do
## Fork worker provisioning in parallel
  make_worker ${i} &
done


## Configure the swarm
docker-machine ssh manager1 "cd alpine-mpich/cluster &&\
  ./swarm.sh config set \
  IMAGE_TAG=eu.gcr.io/bobeas-hpc/nemo:onbuild \
  PROJECT_NAME=bobeas-hpc \
  NETWORK_NAME=bobeas-network \
  NETWORK_SUBNET=10.0.9.0/24 \
  SSH_ADDR=${MANAGER_IP} \
  SSH_PORT=2222"

exit 1

## Spin up the swarm
docker-machine ssh manager1 "cd alpine-mpich/cluster &&\
  ./swarm.sh up size=${NUM_SWARM}"


docker-machine ssh manager1 "cd /SRC/NEMOGCM/CONFIG/TEST/EXP00 &&\
  time mpirun -iface eth0 -wdir /SRC/NEMOGCM/CONFIG/TEST/EXP00 \
     -n 460 /SRC/NEMOGCM/CONFIG/TEST/EXP00/opa : -n 5 /SRC/NEMOGCM/CONFIG/TEST/EXP00/xios_server.exe"
