#!/bin/bash
set -eux

# -----------------------------------------------------------------------------
# docker: docker-compose
# The variable *_VERSION come from the docker build argument DOCKER_COMPOSE_VERSION

TOOLS_MODULE_NAME="docker-compose"
ARCHIVE_FILE="docker-compose-Linux-x86_64"


mkdir -p /usr/local/bin  &&  cd /usr/local/bin
wget --no-clobber --no-verbose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/${ARCHIVE_FILE}

mv ${TOOLS_MODULE_NAME}* "${TOOLS_MODULE_NAME}"
chmod +x -R "${TOOLS_MODULE_NAME}"
