FROM ubuntu:22.04

################## METADATA ##########################

LABEL base.image=ubuntu:22.04
LABEL software="hello-nextflow-batch Image"


################## ARGS #############################

ARG HELLO_PATH="/hello-nextflow/"


################## DEPENDENCIES ######################

# Copy repository
WORKDIR $HELLO_PATH
COPY ./ ./
RUN chmod +x ./bin/*

# Update
RUN apt-get -y update

# Dependencies
RUN bash ./install-all-dependencies.bash


################## ENTRY ######################

CMD bash mystic_cow.bash
