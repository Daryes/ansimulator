#!/bin/bash
# RHEL packages installation
set -eux

# change to current script dir
cd $( dirname $0 )


# yum proxy cache
if [ ! -z "${PKG_RPM_PROXY}" ]; then
    echo "System: yum configuration for a local proxy found - installing ..."
    echo "proxy=${PKG_RPM_PROXY}" >> /etc/yum.conf
fi

# # In case of rocky linux mirror errors
# bash wrapper-packages_install.sh findutils 
# find /etc/yum.repos.d -iname "Rocky-*.repo" -exec sed -i 's/^mirrorlist=/#&/' {} \; -exec sed -i '/^#baseurl=/ s/^#//' {} \;
# yum clean all


# system update
# notice: repos can be unstable on rocky
bash wrapper-packages_upgrade.sh


# specific distrib packages
bash wrapper-packages_install.sh \
    epel-release \
    yum-utils \
    authselect \
    authselect-compat


# general packages
bash wrapper-packages_install.sh \
    rsyslog \
    sudo \
    procps-ng \
    glibc-langpack-en \
    gnupg \
    ca-certificates \
    curl wget \
    tar xz \
    gzip zip unzip \
    nano


# extra packages
bash wrapper-packages_install.sh \
    which \
    iproute \
    net-tools \
    findutils file \
    vim less \
    man


# packages cleanup        
bash wrapper-packages_clean.sh

