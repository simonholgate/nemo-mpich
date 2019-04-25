#!/bin/bash

# Script to provision multiple VMs for Docker Swarm
# Assumes we are on a Google Cloud VM so no credentials are required
PROJECT_ID=bobeas-hpc
GPC_ZONE=europe-west2-a
GPC_MACHINE=n1-standard-96
GPC_MACHINE_MANAGER=n1-standard-96
GPC_DISK=10
GPC_USER=mpi

NUM_WORKERS=4
NUM_SWARM=5
NEMO_CONFIG=INDIAN_OCEAN_AUTO

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

## Make sure we can access docker as USER
  docker-machine ssh worker${1} "sudo usermod -a -G docker ${GPC_USER}"

## Add NFS 
  docker-machine ssh worker${1} 'sudo apt-get update && sudo apt-get install -y nfs-common'

## Upgrade
  docker-machine ssh worker${1} 'sudo unattended-upgrade'

## Login to the container repository with key
  cat bobeas-hpc.json | docker-machine ssh worker${i} \
      "cat | docker login -u _json_key --password-stdin https://eu.gcr.io"

## Join swarm on workers
  docker-machine ssh worker${1} "docker swarm join --token \
    ${WORKER_TOKEN} ${MANAGER_IP}:2377"

## Make NFS mount point on each machine and mount NFS
  docker-machine ssh worker${1} "sudo mkdir -p /mnt/data && sudo mount 10.193.200.114:/vol1 /mnt/data"

  return 0
}


make_manager() {
  docker-machine create --driver google \
    --google-project ${PROJECT_ID} \
    --google-zone ${GPC_ZONE} \
    --google-machine-type ${GPC_MACHINE_MANAGER} \
    --google-disk-size ${GPC_DISK} \
    --google-username ${GPC_USER} \
    manager1
  
  ## Make sure we can access docker as USER
  docker-machine ssh manager1 "sudo usermod -a -G docker ${GPC_USER}"

  ## Add NFS 
  docker-machine ssh manager1 'sudo apt-get update && sudo apt-get install -y nfs-common'

  ## Upgrade
  docker-machine ssh manager1 'sudo unattended-upgrade'

  ## Login to the container repository with key
  cat bobeas-hpc.json | docker-machine ssh manager1 \
      "cat | docker login -u _json_key --password-stdin https://eu.gcr.io"
 
  ## Install docker compose
  docker-machine ssh manager1 \
  'sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)"\
   -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose'
  
  ## Init swarm on manager1
  docker-machine ssh manager1 'MANAGER_IP=`curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip` && docker swarm init --advertise-addr ${MANAGER_IP}'

  ## Make NFS mount point on each machine and mount NFS
  docker-machine ssh manager1 "sudo mkdir -p /mnt/data && sudo mount 10.193.200.114:/vol1 /mnt/data"

  ## Clone git repo
  docker-machine ssh manager1 'git clone https://github.com/simonholgate/nemo-mpich.git'

  ## Fix ssh key permissions
  docker-machine ssh manager1 'chmod 0600 nemo-mpich/cluster/ssh/id_rsa*' 

  ## Add firewall rules to open the required ports - will fail if already defined do delete it first
 # https://gist.github.com/BretFisher/7233b7ecf14bc49eb47715bbeb2a2769
  gcloud compute firewall-rules delete swarm-machines --quiet
  gcloud compute firewall-rules create swarm-machines \
     --allow "tcp:22,tcp:2377,tcp:7946,tcp:10000-11000,udp:10000-11000,udp:4789,udp:7946,50" \
     --source-ranges 0.0.0.0/0 \
     --target-tags docker-machine \
     --project ${PROJECT_ID} \
     --quiet
}

configure_swarm(){
  docker-machine ssh manager1 "cd nemo-mpich/cluster &&\
    ./swarm.sh config set \
    IMAGE_TAG=eu.gcr.io/bobeas-hpc/nemo:onbuild \
    PROJECT_NAME=bobeas-hpc \
    NETWORK_NAME=bobeas-network \
    NETWORK_SUBNET=10.0.9.0/24 \
    SSH_ADDR=${MANAGER_IP} \
    SSH_PORT=2222"
}

spinup_swarm() {
  docker-machine ssh manager1 "cd nemo-mpich/cluster &&\
    ./swarm.sh up size=${NUM_SWARM}"
}

run_model() {
  docker-machine ssh manager1 "./swarm.sh exec 
    \x22NEMO_CONFIG=${NEMO_CONFIG} &&\
    cd /SRC/NEMOGCM/CONFIG/${NEMO_CONFIG}/EXP00 &&\
    mpiexec hostname | sort -u > hosts &&\
    NPN=392; NPX=4; \
       HYDRA_TOPO_DEBUG=1 time mpiexec -iface eth0 -f hosts \
       -wdir /SRC/NEMOGCM/CONFIG/${NEMO_CONFIG}/EXP00 \
       -n ${NPX} /SRC/NEMOGCM/CONFIG/${NEMO_CONFIG}/EXP00/xios_server.exe :\
       -n ${NPN} /SRC/NEMOGCM/CONFIG/${NEMO_CONFIG}/EXP00/opa :\
       -bind-to socket -map-by hwthread /bin/true | sort -k 2 -n\x22"
}

#*****************************#
### Provision manager first ###
#*****************************#

make_manager()

#*****************************#
###   Provision workers     ###
#*****************************#

WORKER_TOKEN=`docker-machine ssh manager1 "docker swarm join-token worker -q"`
MANAGER_IP=`docker-machine ip manager1`

for (( i=1 ; i<=${NUM_WORKERS}; i++ ));
do
## Fork worker provisioning in parallel
  make_worker ${i} &
done

#*****************************#
###   Configure the swarm   ###
#*****************************#
configure_swarm()

### Command to be run on the manager after provisioning
## Spin up the swarm
#spinup_swarm()

### Command to be run on the container after swarm has spun up
## Run the model
#run_model()

exit 0
