#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# ref : https://github.com/haidaraM/ansible-playbook-grapher

# adjust for ansible version
if echo "$ANSIBLE_VERSION" | egrep -q '^2\.9\.'; then ANSIBLE_PLAYBOOK_GRAPHER_VERSION=1.0.0.dev4; fi


if [ ! -z "$ANSIBLE_PLAYBOOK_GRAPHER_VERSION" ]; then
    ANSIBLE_PLAYBOOK_GRAPHER_VERSION="==$ANSIBLE_PLAYBOOK_GRAPHER_VERSION"; 
fi

# requirement
bash wrapper-packages_install.sh \
        graphviz


# ansible: python requirements and installation
export PIP_ROOT_USER_ACTION=ignore
python3 -m pip install --upgrade --no-cache ansible-playbook-grapher$ANSIBLE_PLAYBOOK_GRAPHER_VERSION


# cleanup
bash wrapper-packages_clean.sh
