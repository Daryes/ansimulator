#!/bin/bash
set -eux


case $BASE_SYSTEM in
    debian)
        apt-get update
        apt-get upgrade -y
        ;;

    rhel|redhat)
        yum update -y
        yum upgrade -y
        ;;

    *)
        echo "Unknown distribution: $BASE_SYSTEM"; exit 1
 esac
