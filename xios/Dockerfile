### Installs the framework for the NEMO Ocean Engine compilation ###
####################################################################
FROM eu.gcr.io/bobeas-hpc/nemo/base:v1 as base
FROM eu.gcr.io/bobeas-hpc/debian:jessie as xios

# Based on NEMO-Docker by Pierre Derian, contact@pierrederian.net, www.pierrederian.net
MAINTAINER Simon Holgate <hello@simonholgate.org.uk> 
ARG NEMO_CONFIG=TEST

COPY --from=base /usr/local /usr/local

USER root

### dependencies for NEMO:
# bash, perl, svn, fortran90 compiler, mpi, netcdf, netcdf-fortran, make
# from http://www.nemo-ocean.eu/Using-NEMO/User-Guides/Basics/NEMO-Quick-Start-Guide
### dependencies for XIOS: netcdf4 hdf5
# from http://forge.ipsl.jussieu.fr/ioserver/wiki/documentation
### notes:
# ssh is required in order for MPI to run properly
# nano, python2.7 are not mandatory but useful when we have to work in the container
ENV PACKAGES="subversion make gcc g++ ssh nfs-common"
ENV PACKAGES_NEMO="perl gfortran"
ENV PACKAGES_XIOS="liburi-perl zlib1g zlib1g-dev libcurl3"

### first update then install the main packages
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends ${PACKAGES} ${PACKAGES_NEMO} ${PACKAGES_XIOS} 

ENV CONFIG ${NEMO_CONFIG}
ENV WDIR /SRC
ENV MNT_DIR /mnt/data
ENV XDIR ${WDIR}/XIOS
ENV INPUTS ${WDIR}/INPUTS
ENV START_FILES ${WDIR}/START_FILES
ENV CDIR ${WDIR}/NEMOGCM/CONFIG
ENV TDIR ${WDIR}/NEMOGCM/TOOLS
ENV EXP ${CDIR}/$CONFIG/EXP00

RUN mkdir ${WDIR} && mkdir -p ${MNT_DIR}

WORKDIR ${WDIR}

#RUN svn co -r 9709 \
#    http://forge.ipsl.jussieu.fr/nemo/svn/branches/UKMO/dev_r8814_surge_modelling_Nemo4/NEMOGCM NEMOGCM
RUN svn co http://forge.ipsl.jussieu.fr/nemo/svn/trunk/NEMOGCM@8395 trunk_NEMOGCM_r8395 \
    && ln -s trunk_NEMOGCM_r8395 NEMOGCM

RUN svn co http://forge.ipsl.jussieu.fr/ioserver/svn/XIOS/branchs/xios-2.5 xios-2.5_head \
    && ln -s xios-2.5_head XIOS

COPY arch_NEMOGCM/arch* NEMOGCM/ARCH/
COPY arch_XIOS/arch* XIOS/arch/

WORKDIR ${XDIR}
# Enable test_client to be built
RUN sed -i "s/#bld::target test_client.exe/bld::target test_client.exe/" /SRC/XIOS/bld.cfg
# Build XIOS
RUN ./make_xios --full --prod --netcdf_lib netcdf4_par --arch DEBIAN

WORKDIR ${CDIR}

RUN echo "Y N N N N N N N" | ./makenemo -n ${CONFIG} -m DEBIAN clean
RUN ln -s  ${XDIR}/bin/xios_server.exe ${EXP}/xios_server.exe

COPY cpp_INDIAN_OCEAN.fcm ${CONFIG}/cpp_${CONFIG}.fcm
ADD MY_SRC.tar.gz ${CONFIG}/

RUN echo "Y N N N N N N N" | ./makenemo -n ${CONFIG} -m DEBIAN 
