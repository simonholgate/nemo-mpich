FROM eu.gcr.io/bobeas-hpc/nemo/xios:v4 as xios
FROM eu.gcr.io/bobeas-hpc/debian:jessie as onbuild

# Based on alpine-mpich by Nikyle Nguyen <NLKNguyen@MSN.com>
MAINTAINER Simon Holgate <hello@simonholgate.org.uk>

ARG NEMO_CONFIG=TEST
ARG NEMO_USER=mpi

COPY --from=xios /usr/local /usr/local

USER root

# bind-tools gives us 'dig'. nfs-utils allows mounting of nfs volume
RUN apt-get update && apt-get install -y libcurl3 gfortran ssh dnsutils zlib1g m4 nfs-common sudo \
  --no-install-recommends && apt-get clean

# # ------------------------------------------------------------
# # Utility shell scripts
# # ------------------------------------------------------------

COPY mpi_bootstrap /usr/local/bin/mpi_bootstrap
RUN chmod +x /usr/local/bin/mpi_bootstrap

COPY get_hosts /usr/local/bin/get_hosts
RUN chmod +x /usr/local/bin/get_hosts

COPY auto_update_hosts /usr/local/bin/auto_update_hosts
RUN chmod +x /usr/local/bin/auto_update_hosts

# # ------------------------------------------------------------
# # Miscellaneous setup for better user experience
# # ------------------------------------------------------------

RUN rm -rf /SRC && mkdir -p /mnt/data && ln -s /mnt/data/crisc/ /SRC
# Run directory for the CRISC model
ENV EXP /SRC/NEMOGCM/CONFIG/${NEMO_CONFIG}/EXP00

# Default hostfile location for mpirun. This file will be updated automatically.
ENV HYDRA_HOST_FILE /etc/opt/hosts
RUN mkdir -p /etc/opt
RUN echo "export HYDRA_HOST_FILE=${HYDRA_HOST_FILE}" >> /etc/profile
RUN echo "export EXP=${EXP}" >> /etc/profile
# Set ports that MPICH should use. Needs to be open on firewall - see provison.sh
RUN echo "export MPIR_CVAR_CH3_PORT_RANGE=10000:11000" >> /etc/profile

RUN touch ${HYDRA_HOST_FILE}
RUN chown ${USER}:${USER} ${HYDRA_HOST_FILE}

#### ADD DEFAULT USER ####
ARG USER=${NEMO_USER}
ENV USER_HOME /home/${USER}
RUN useradd -d ${USER_HOME} -m ${USER} -s /bin/bash \
      && echo "${USER}   ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN chown -R ${USER}:${USER} ${USER_HOME}

#### CREATE WORKING DIRECTORY FOR USER ####
ARG WORKDIR=/project
ENV WORKDIR ${WORKDIR}
RUN mkdir ${WORKDIR}
RUN chown -R ${USER}:${USER} ${WORKDIR}

WORKDIR ${WORKDIR}
USER ${USER}


# # ------------------------------------------------------------
# # Set up SSH Server 
# # ------------------------------------------------------------
USER root
# We don't want SSH running from init.d
RUN update-rc.d -f ssh remove

# Add host keys
RUN cd /etc/ssh/ && ssh-keygen -A -N ''

# Config SSH Daemon
RUN mkdir /var/run/sshd
RUN echo 'root:MpiPwd1' | chpasswd
RUN echo 'mpi:MpiPwd1' | chpasswd
RUN  sed -i "s/#PasswordAuthentication.*/PasswordAuthentication no/g" /etc/ssh/sshd_config \
  && sed -i "s/PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config \
  && sed -i "s/UsePAM yes/#UsePAM yes/g" /etc/ssh/sshd_config \
  && sed -i "s/#AuthorizedKeysFile/AuthorizedKeysFile/g" /etc/ssh/sshd_config \
  && echo "AllowUsers root mpi" >> /etc/ssh/sshd_config
 
# Set up user's public and private keys
ENV SSHDIR ${USER_HOME}/.ssh
RUN mkdir -p ${SSHDIR}

# Default ssh config file that skips (yes/no) question when first login to the host
RUN echo "StrictHostKeyChecking no" > ${SSHDIR}/config
# This file can be overwritten by the following onbuild step if ssh/ directory has config file

# # ------------------------------------------------------------
# # ONBUILD (require ssh/ directory in the build context)
# # ------------------------------------------------------------
ONBUILD USER root

ONBUILD COPY ssh/ ${SSHDIR}/

ONBUILD RUN cat ${SSHDIR}/*.pub >> ${SSHDIR}/authorized_keys
ONBUILD RUN chmod -R 0600 ${SSHDIR}/* \
         && chown -R ${USER}:${USER} ${SSHDIR}

# Switch back to default user when continue the build process
ONBUILD USER ${USER}
