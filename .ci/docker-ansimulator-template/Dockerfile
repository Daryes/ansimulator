# This file contains the definition for both the redhat/centos and debian image sources, and the common part
# build with the following arguments : --build-arg IMAGE_DEBIAN_REF=debian:10  --build-arg IMAGE_CENTOS_REF=rockylinux:8  --build-arg TARGET_DIST=<redhat or debian>
# the related distrib image will be created, and the others dropped
# Notice: the .ci/docker-compose.ansimulator.env file contains the distribution names and versions used here

# due to the multi-stage, all ARG related to reference images must be defined together before at least the 2nd FROM
ARG TARGET_DIST
ARG IMAGE_CENTOS_NAME=rockylinux
ARG IMAGE_CENTOS_VERSION=latest
ARG IMAGE_DEBIAN_NAME=debian
ARG IMAGE_DEBIAN_VERSION=latest


#______________________________________________________________________________
# ref: https://hub.docker.com/_/rockylinux
FROM $IMAGE_CENTOS_NAME:$IMAGE_CENTOS_VERSION as build-redhat
ENV BASE_SYSTEM=redhat


#______________________________________________________________________________
# ref: https://hub.docker.com/_/debian
FROM $IMAGE_DEBIAN_NAME:$IMAGE_DEBIAN_VERSION as build-debian
ENV BASE_SYSTEM=debian


#______________________________________________________________________________
FROM build-${TARGET_DIST} as final
ENV container=docker

ARG PKG_APT_PROXY=
ARG PKG_YUM_PROXY=
# ARG ANSIBLE_USER_UID <= declared in the ansible section

# don't forget to update the IMAGE_* variables in the file: .ci/docker-compose.env
LABEL dockerfile.date=20230201

LABEL company.name='World Company'
LABEL company.entity=Devops
LABEL app.image=ansimulator/${BASE_SYSTEM}-systemd-ssh
LABEL app.name=ansible
LABEL app.module=systemd+ssh
LABEL app.description="Living the dream"
LABEL app.mode=build


# specific container configuration and variables
SHELL ["/bin/bash", "-o", "pipefail", "-c" ]
ENV INSTALL_SCRIPTS /tmp/install
ENV PYTHONUNBUFFERED 1
ENV DEBIAN_FRONTEND noninteractive


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
ENV init /lib/systemd/systemd
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

ENV DOCKER_COMPOSE_VERSION="1.29.2"
ENV DOCKER_LS_VERSION="0.5.1"

ENV INSTALL_MODULE_NAME="DinD"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh" && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"

# mandatory volume for DinD
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
# ansible      2.9  : python 3.5+	ansible-lint=4.3.7	ansible-playbook-grapher=1.0.0.dev4
# ansible-core 2.12 : Python 3.8+	ansible-lint=6.9	ansible-playbook-grapher=2.0.0
# ansible-core 2.14 : Python 3.9+	ansible-lint=6.10+	ansible-playbook-grapher=2.0.0
# ansible-core 2.15 : Python 3.9+	ansible-lint=6.*	ansible-playbook-grapher=2.*


# .* is required for the latest sub-version instead of an automatic .0 version
# Warning : update also the compose.env file for a system release version supporting natively the related python version.
ENV ANSIBLE_VERSION=2.9.*
#ENV ANSIBLE_VERSION=2.15.*

# set to empty for the latest version -  will be downgraded to 1.0.0.dev4 for ansible 2.9
ENV ANSIBLE_LINT_VERSION=

# set to empty for the latest version -  will be downgraded to 4.3.7 for ansible 2.9
ENV ANSIBLE_PLAYBOOK_GRAPHER_VERSION=


# ansible user uid - set as ARG to allow changing the value
ARG ANSIBLE_USER_UID=421


ENV INSTALL_MODULE_NAME="ansible"
COPY wrapper-*.sh "$INSTALL_MODULE_NAME/"  "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"
RUN bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install.sh" \
    && bash "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/install-playbook-grapher.sh" \
    && rm -rf "$INSTALL_SCRIPTS/$INSTALL_MODULE_NAME/"


# required for sharing keys between images
VOLUME /home/ansible/.ssh

# fix for ansible warning about the cfg access mode
ENV ANSIBLE_CONFIG=/etc/ansible/ansible.cfg

# fix for host key validation - disabling is required for disposable containers
ENV ANSIBLE_HOST_KEY_CHECKING=False

# fix for custom environment
RUN mkdir -p /server/ansible/ansible  ;\
	chown -R ansible: /server/ansible  ;\
	ln -s /home/ansible/.ansible/collections /server/ansible/ansible/  ;\
	install --owner ansible --group ansible --mode 755 -d /var/log/ansible

# -----------------------------------------------------------------------------
RUN rmdir "$INSTALL_SCRIPTS"
#ENTRYPOINT [ "/usr/sbin/sshd", "-De" ]
#ENTRYPOINT ["/lib/systemd/systemd"]
CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
