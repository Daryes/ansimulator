#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------

# execute the dedicated package installation script for the current system
bash install_dist-${BASE_SYSTEM}.sh


# purge installed locales
# TODO: use the package localepurge instead
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d ! -name 'en*' | xargs --no-run-if-empty rm -r


# timezone
if [ -d timezone ]; then
    # supported values are taken from /usr/share/zoneinfo/
    cp timezone/timezone /etc/
else
    echo "Etc/UTC" > /etc/timezone
fi


# profile.d
if [ -d profile.d ]; then
    cp profile.d/* /etc/profile.d/
fi
