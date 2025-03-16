#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# ref : https://github.com/haidaraM/ansible-playbook-grapher

ANSIBLE_PIP_EXTRA_ARGS=""
if [ "$BASE_SYSTEM" == "debian" ]; then
  ANSIBLE_PIP_EXTRA_ARGS="--break-system-packages"
fi

# adjust for ansible version
case "$ANSIBLE_VERSION" in

  2.9.*)
    ANSIBLE_PLAYBOOK_GRAPHER_VERSION="1.0.0.dev4"
    ANSIBLE_PIP_EXTRA_ARGS=""
    ;;

  2.1[234].*)
    ANSIBLE_PLAYBOOK_GRAPHER_VERSION="2.0.0"
    ANSIBLE_PIP_EXTRA_ARGS=""
    ;;

  2.15.*)
    ANSIBLE_PLAYBOOK_GRAPHER_VERSION="2.2.1"
    ANSIBLE_PIP_EXTRA_ARGS=""
    ;;

  2.16.*)
    # no release available yet for Rocky with python3 >= 3.10
    if [ "$BASE_SYSTEM" == "redhat" ]; then
      if grep -q -i --fixed-strings 'VERSION_ID="9.' /etc/os-release; then
        shopt -s expand_aliases
        alias python3=/usr/bin/python3.11
      fi
    fi
    ;;

esac



if [ ! -z "$ANSIBLE_PLAYBOOK_GRAPHER_VERSION" ]; then
    ANSIBLE_PLAYBOOK_GRAPHER_VERSION="==$ANSIBLE_PLAYBOOK_GRAPHER_VERSION"; 
fi

# requirement
bash wrapper-packages_install.sh \
        graphviz


# ansible: python requirements and installation
export PIP_ROOT_USER_ACTION=ignore
python3 -m pip install --upgrade --no-cache ${ANSIBLE_PIP_EXTRA_ARGS} ansible-playbook-grapher$ANSIBLE_PLAYBOOK_GRAPHER_VERSION


# cleanup
bash wrapper-packages_clean.sh
