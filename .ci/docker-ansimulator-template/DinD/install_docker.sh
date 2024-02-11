#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# Docker packages and installation (latest)


# group creation - ensure the same GID for all instances
if ! getent group docker &>/dev/null; then groupadd -r docker --gid=987; fi


# package requirements
bash wrapper-packages_install.sh \
    ca-certificates \
    curl \
    gnupg2 \
    iptables

# package requirements - specifics
if command -v apt-get &>/dev/null; then
    bash wrapper-packages_install.sh \
        apt-transport-https \
        software-properties-common \
        linux-headers-amd64

    # install docker.io key and repo
    curl -fsSL https://download.docker.com/linux/debian/gpg | tee /etc/apt/trusted.gpg.d/docker-ce.asc 1>/dev/null || exit 1

    add-apt-repository \
       "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/docker-ce.asc] \
       https://download.docker.com/linux/$(lsb_release -is |tr '[:upper:]' '[:lower:]') \
       $(lsb_release -cs) \
       stable"

else
    bash wrapper-packages_install.sh \
        yum-utils

    # install docker.io key and repo
    yum-config-manager \
        --add-repo \
        https://download.docker.com/linux/centos/docker-ce.repo
fi


# fix for WSL - nftables not supported
# ref: https://github.com/microsoft/WSL/issues/6655
# notice : iptables-legacy does not exist on RHEL/Centos 8
if uname -a |grep -q WSL; then
    update-alternatives --set iptables /usr/sbin/iptables-legacy    || true
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy  || true
fi


# install docker
bash wrapper-packages_install.sh docker-ce docker-ce-cli containerd.io


# cleanup
bash wrapper-packages_clean.sh
