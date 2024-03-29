#!/bin/sh
# ref: https://raw.githubusercontent.com/solita/docker-systemd/master/setup
# this script must be run with sudo

set -eu

if nsenter --mount=/proc/1/ns/mnt -- mount | grep /sys/fs/cgroup/systemd >/dev/null 2>&1; then
  echo 'The systemd cgroup hierarchy is already mounted at /sys/fs/cgroup/systemd.'
else
  if [ -d /sys/fs/cgroup/systemd ]; then
    echo 'The mount point for the systemd cgroup hierarchy already exists at /sys/fs/cgroup/systemd.'
  else
    echo 'Creating the mount point for the systemd cgroup hierarchy at /sys/fs/cgroup/systemd.'
    mkdir -p /sys/fs/cgroup/systemd
  fi

  echo 'Mounting the systemd cgroup hierarchy.'
  nsenter --mount=/proc/1/ns/mnt -- mount -t cgroup cgroup -o none,name=systemd /sys/fs/cgroup/systemd
fi
echo 'Your Docker host is now configured for running systemd containers!'
