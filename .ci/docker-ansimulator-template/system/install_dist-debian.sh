#!/bin/bash
# Debian packages installation
set -eux

# change to current script dir
cd $( dirname $0 )


# apt config for containers
cp -v apt/docker-reduce-footprint /etc/apt/apt.conf.d/docker-reduce-footprint
[ -f /etc/cron.daily/apt-compat ] && rm /etc/cron.daily/apt-compat


# apt proxy cache
if [ ! -z "${PKG_DEB_PROXY}" ]; then
    echo "System: apt configuration for a local proxy found - installing ..."

    # removing any proto in front and split IP and port
    PKG_DEB_PROXY="${PKG_DEB_PROXY##*://}"
    PKG_DEB_PROXY_IP="${PKG_DEB_PROXY%%:*}"
    PKG_DEB_PROXY_PORT="${PKG_DEB_PROXY##*:}"

    # requires netcat first
    apt-get update && apt-get install -y netcat-openbsd apt-transport-https apt-utils

    cp -av apt_local_proxy/* /etc/apt/
    sed -i "s#=deb-cache.domain.tld#=${PKG_DEB_PROXY_IP}#g"  /etc/apt/detect_proxy.conf
    sed -i "s#=3142#=${PKG_DEB_PROXY_PORT}#g"  /etc/apt/detect_proxy.conf
    chmod +x /etc/apt/detect_proxy.sh
fi


# system update
bash wrapper-packages_upgrade.sh


# specific distrib packages
bash wrapper-packages_install.sh \
    lsb-release \
    apt-utils \
    python3-apt


# general packages
bash wrapper-packages_install.sh \
    rsyslog \
    sudo \
    procps \
    locales \
    gnupg \
    ca-certificates \
    curl wget \
    tar xz-utils \
    gzip zip unzip \
    nano


# extra packages
bash wrapper-packages_install.sh \
    debianutils \
    iproute2 \
    iputils-ping net-tools \
    findutils file \
    vim-tiny less \
    man


# packages cleanup        
bash wrapper-packages_clean.sh

