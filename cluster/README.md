NEMO MPICH Cluster
====================

Scaffolding project structure for a MPI cluster using [NEMO MPICH](http://eu.gcr.io/bobeas-hpc/nemo) Docker image. Architecturally compatible with *Docker Swarm Mode*. Include a runner script that automates Docker commands.

Original software targets:
- Docker Engine version 18.09.1


Currently, this directory provides two ways to orchestrate the cluster (with different files requirement):
+ Using Docker Compose to replicate production environment on single Docker host
+ Using Docker Swarm Mode for real production environment across multiple Docker hosts.


# For single-host with Docker Compose - IN DEVELOPMENT

Require **Docker Compose**; target version 1.8.0

Documentation: [alpine-mpich wiki](https://github.com/NLKNguyen/alpine-mpich/wiki/Single-Host-Orchestration)

Relevant files:

```
cluster
├── Dockerfile          # Image specification
├── project             # Sample program source code
│   └── mpi_hello_world.c
├── ssh                 # keys for accessing
│   ├── id_rsa          # (could generate your own)
│   └── id_rsa.pub
├── .env                # General configuration
├── docker-compose.yml  # Container orchestration 
└── cluster.sh          # Commands wrapper ultility
```

# For multi-host with Docker Swarm Mode - TESTED AND WORKING

Require being on a **Docker Swarm** manager (could be a single local machine) and having access to an image registry (could use Docker Hub) 

Documentation: [alpine-mpich wiki](https://github.com/NLKNguyen/alpine-mpich/wiki/Multi-Host-Orchestration)

Relevant files:

```
cluster
├── Dockerfile          # Image specification
├── project             # Sample program source code
│   └── mpi_hello_world.c
├── ssh                 # keys for accessing
│   ├── id_rsa          # (could generate your own)
│   └── id_rsa.pub
└── swarm.sh            # Commands wrapper ultility

```
