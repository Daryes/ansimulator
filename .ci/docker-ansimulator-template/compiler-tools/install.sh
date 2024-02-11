#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------

# extra system packages
bash wrapper-packages_install.sh \
        make \
        cmake \
        gnupg \
        git \
        dos2unix


# installing maven
if [ -s maven/install.sh ]; then bash maven/install.sh; fi


# cleanup
bash wrapper-packages_clean.sh

