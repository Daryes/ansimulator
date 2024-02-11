#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------

# Some names are not the same depending of the distrib
PACKAGE_CLIENT="systemd-sysv init"
command -v yum &>/dev/null && PACKAGE_CLIENT="initscripts"


# systemd
# ref: https://developers.redhat.com/blog/2014/05/05/running-systemd-within-docker-container
# ref: https://github.com/solita/docker-systemd

# install packages
bash wrapper-packages_install.sh \
	bash \
	systemd \
	${PACKAGE_CLIENT}


# remove unecessary files
find /etc/systemd/system \
    /lib/systemd/system \
    -path '*.wants/*' \
    -not -name '*journald*' \
    -not -name '*systemd-tmpfiles*' \
    -not -name '*systemd-user-sessions*' \
    -exec rm \{} \;


# activate
systemctl set-default multi-user.target
systemctl mask dev-hugepages.mount sys-fs-fuse-connections.mount || true
install --owner root --group systemd-journal --mode 2755 -d /var/log/journal

# /sbin/init fix depending of the version
if [ ! -s /sbin/init ]; then 
	ln -s /lib/systemd/systemd /sbin/init
fi


# dbus requirement
bash wrapper-packages_install.sh \
        dbus

if [ ! -s /lib/systemd/system/sockets.target.wants/dbus.socket ]; then
	ln -s /lib/systemd/system/dbus.socket /lib/systemd/system/sockets.target.wants/dbus.socket
fi


# cleanup
bash wrapper-packages_clean.sh


echo '
To activate systemd, the image has these additionnal requirements:
  * init command: ENTRYPOINT ["/lib/systemd/systemd"]
    (alt) or for debian : CMD [ "/lib/systemd/systemd", "log-level=info", "unit=sysinit.target" ]
    (alt) or : CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]
  * variables: ENV init /lib/systemd/systemd
  * stopsignal: STOPSIGNAL SIGRTMIN+3
  * volumes: -v /sys/fs/cgroup:/sys/fs/cgroup:rw
  * tmpfs: --tmpfs /run --tmpfs /run/lock
  * security: --security-opt seccomp=unconfined
  * capabilities: --cap-add SYS_ADMIN
  * cgroup: --cgroups host
'
