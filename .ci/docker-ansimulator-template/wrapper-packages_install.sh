#!/bin/bash
set -eux

if [ "$#" -eq 0 ]; then echo "Error: no package names provided"; exit 1; fi


case $BASE_SYSTEM in
    debian)
        apt-get update
        apt-get install --no-install-recommends -y "$@"
        ;;

    rhel|redhat)
        yum makecache -y
        yum install --allowerasing -y "$@"
        ;;

    *)
        echo "Unknown distribution: $BASE_SYSTEM"; exit 1
 esac
