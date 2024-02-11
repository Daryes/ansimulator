#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# Docker packages and installation (latest)

if uname -a |egrep -q -i "microsoft.*WSL" && egrep -q -i "rhel|centos|rocky" /etc/os-release; then
    echo "WARNING: docker in docker does not work correctly on RHEL / Centos on WSL2"
    echo "Use a debian image instead"
fi


# group creation - ensure the same GID for all instances
if ! getent group docker &>/dev/null; then groupadd -r docker --gid=987; fi


# DinD requirements
bash wrapper-packages_install.sh \
    iptables \
    findutils 


# package requirements - specifics
if command -v apt-get &>/dev/null; then
    bash wrapper-packages_install.sh \
        apt-transport-https \
        software-properties-common \
        init

else
    bash wrapper-packages_install.sh \
        yum-utils \
        initscripts
fi


# fix for WSL - nftables not supported
# ref: https://github.com/microsoft/WSL/issues/6655
# notice : iptables-legacy does not exist on RHEL/Centos 8
if uname -a |grep -q WSL; then
    update-alternatives --set iptables /usr/sbin/iptables-legacy    || true
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy  || true
fi


# cleanup
bash wrapper-packages_clean.sh


# copy DinD activation script
# ref: https://hub.docker.com/_/docker/
# ref: https://github.com/moby/moby/blob/master/hack/dind
cp dind /usr/local/bin/dind
chmod +x /usr/local/bin/dind

# handle systemd presence
if [ -x "/lib/systemd/systemd" ]; then
    # in case the services are already available, not a real problem otherwise
	systemctl disable docker.service        || true
	systemctl disable containerd.service    || true

	cp dind.service /etc/systemd/system/dind.service	
	ln -s /etc/systemd/system/dind.service /etc/systemd/system/multi-user.target.wants/
fi


echo '
To activate Docker in docker (dind), the image requires these additionnal requirements:
  * the image must be started with "--privileged"
  * volume declaration (can be mapped to an empty volume): VOLUME /var/lib/docker
  * this command ran as root in the container on start if systemd is not used: /usr/local/bin/dind service docker start
'
