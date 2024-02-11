#!/bin/bash
set -eux


case $BASE_SYSTEM in
    debian)
        apt-get autoremove -y && apt-get clean && find /var/lib/apt/lists/ -type f -delete
        ;;

    rhel|redhat)
        yum autoremove -y && yum clean all
        ;;

    *)
        echo "Unknown distribution: $BASE_SYSTEM"; exit 1
esac

