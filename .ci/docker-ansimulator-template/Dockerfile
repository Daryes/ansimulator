# check=skip=SecretsUsedInArgOrEnv
#
# This file contains the definition for both the redhat/centos and debian image sources, and the common part
# build with the following arguments : --build-arg IMAGE_DEBIAN_REF=debian:10  --build-arg IMAGE_CENTOS_REF=rockylinux:8  --build-arg TARGET_DIST=<redhat or debian>
# the related distrib image will be created, and the others dropped
# Notice: the .ci/docker-compose.ansimulator.env file contains the distribution names and versions used here

# due to the multi-stage, all ARG related to reference images must be defined together before at least the 2nd FROM
ARG TARGET_DIST=debian
ARG IMAGE_CENTOS_NAME=rockylinux
ARG IMAGE_CENTOS_VERSION=latest
ARG IMAGE_DEBIAN_NAME=debian
ARG IMAGE_DEBIAN_VERSION=latest


#______________________________________________________________________________
# ref: https://hub.docker.com/_/rockylinux
FROM $IMAGE_CENTOS_NAME:$IMAGE_CENTOS_VERSION AS build-redhat
ENV BASE_SYSTEM=redhat


#______________________________________________________________________________
# ref: https://hub.docker.com/_/debian
FROM $IMAGE_DEBIAN_NAME:$IMAGE_DEBIAN_VERSION AS build-debian
ENV BASE_SYSTEM=debian


#______________________________________________________________________________
FROM build-${TARGET_DIST} AS final
ENV container=docker

ARG PKG_DEB_PROXY=
ARG PKG_RPM_PROXY=
# ARG ANSIBLE_USER_UID <= declared in the ansible section

# don't forget to update the IMAGE_* variables in the file: .ci/docker-compose.ansimulator.env
LABEL dockerfile.date=20250216

LABEL company.name='World Company'
LABEL company.entity=Devops
LABEL app.image=ansimulator/${BASE_SYSTEM}-systemd-ssh
LABEL app.name=ansible
LABEL app.module=systemd+ssh
LABEL app.description="Living the dream"
LABEL app.mode=build


# specific container configuration and variables
SHELL ["/bin/bash", "-o", "pipefail", "-c" ]
ENV INSTALL_SCRIPTS="/tmp/install"
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND="noninteractive"


# -----------------------------------------------------------------------------
# System configuration and packages

ENV INSTALL_MODULE_NAME="system"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh" && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"


# -----------------------------------------------------------------------------
# Systemd configuration and packages

ENV INSTALL_MODULE_NAME="systemd"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh" && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"

# mandatory for systemd
ENV init="/lib/systemd/systemd"
STOPSIGNAL SIGRTMIN+3


# -----------------------------------------------------------------------------
# sshd configuration and packages

ENV INSTALL_MODULE_NAME="sshd"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh" && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"

# mandatory for sshd
EXPOSE 22


## -----------------------------------------------------------------------------
## Docker packages and installation (latest)

# ref: https://github.com/docker/compose/releases
ENV DOCKER_COMPOSE_VERSION="2.38.2"
# ref: https://github.com/mayflower/docker-ls
ENV DOCKER_LS_VERSION="0.5.1"

ENV INSTALL_MODULE_NAME="DinD"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh" && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"

# mandatory volume for DinD - no host sharing is required but it must exists
VOLUME /var/lib/docker


# -----------------------------------------------------------------------------
# Compiler tools configuration and packages

ENV INSTALL_MODULE_NAME="compiler-tools"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh" && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"


# -----------------------------------------------------------------------------
# ansible

# Version matrix
# ref: https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-core-support-matrix
# ref: https://github.com/ansible/ansible-lint/blob/main/.config/requirements.in
# ref: https://github.com/haidaraM/ansible-playbook-grapher/blob/main/requirements.txt
# ansible      2.9  : python 3.5-3.8	ansible-lint=4.3.7	ansible-playbook-grapher=1.0.0.dev4
# ansible-core 2.12 : Python 3.8-3.10	ansible-lint=6.9	ansible-playbook-grapher=2.0.0
# ansible-core 2.14 : Python 3.9-3.11	ansible-lint=6.10+	ansible-playbook-grapher=2.0.0
# ansible-core 2.15 : Python 3.9-3.11	ansible-lint=6.*	ansible-playbook-grapher=2.2.1
# ansible-core 2.16 : Python 3.10-3.12	ansible-lint=24+	ansible-playbook-grapher=2+
# ansible-core 2.19 : Python 3.11-3.13	ansible-lint=25.7+	ansible-playbook-grapher=not yet


# .* is required for the latest sub-version otherwise the .0 version will be automatically selected
# Warning : update also the compose.env file for a system release version supporting natively the related python version.
#ENV ANSIBLE_VERSION=2.9.*
ENV ANSIBLE_VERSION=2.16.*

# ansible user uid - set as ARG to allow changing the value
ARG ANSIBLE_USER_UID=421


ENV INSTALL_MODULE_NAME="ansible"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN $INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh --debug \
		--ansible-version "${ANSIBLE_VERSION}"  \
		--user-uid ${ANSIBLE_USER_UID}  \
		--install-ansible-lint  \
		--install-ansible-navigator  \
		--install-playbook-grapher  \
    && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"


# required for sharing keys between images
VOLUME /home/ansible/.ssh

# fix for ansible warning about the cfg access mode
ENV ANSIBLE_CONFIG=/etc/ansible/ansible.cfg

# fix for host key validation - disabling is required for disposable containers
ENV ANSIBLE_HOST_KEY_CHECKING=False

# handle the custom environment
RUN mkdir -p /server/ansible/ansible  ;\
	chown -R ansible: /server/ansible  ;\
	ln -s /home/ansible/.ansible/collections /server/ansible/ansible/  ;\
	install --owner ansible --group ansible --mode 755 -d /var/log/ansible


# configuration for ansible-navigator
ENV ANSIBLE_NAVIGATOR_EXECUTION_ENVIRONMENT=false
ENV ANSIBLE_NAVIGATOR_LOG_FILE=/tmp/ansible-navigator.log


# -----------------------------------------------------------------------------
RUN rmdir "$INSTALL_SCRIPTS"
#ENTRYPOINT [ "/usr/sbin/sshd", "-De" ]
#ENTRYPOINT ["/lib/systemd/systemd"]
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]

