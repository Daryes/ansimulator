#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# install DinD if available, but for docker, only if requested
INSTALL_DOCKER=${INSTALL_DOCKER:-0}


TARGET_SCRIPT=install_dind.sh
if [ -s $TARGET_SCRIPT ]; then bash $TARGET_SCRIPT; fi


if [ "$INSTALL_DOCKER" != "0" ]; then 
    TARGET_SCRIPT=install_docker.sh
    bash $TARGET_SCRIPT

    TARGET_SCRIPT=install_docker-compose.sh
    if [ -s $TARGET_SCRIPT ]; then bash $TARGET_SCRIPT; fi
fi


# install docker-ls if available
TARGET_SCRIPT=install_docker-ls.sh
if [ -s $TARGET_SCRIPT ]; then bash $TARGET_SCRIPT; fi
