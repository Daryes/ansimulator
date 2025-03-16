#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# The variables *_VERSION and ANSIBLE_USER_UID come from the docker build argument 
ANSIBLE_HOME_DIR=/home/ansible

ANSIBLE_PACKAGE_NAME=ansible-core
ANSIBLE_PYTHON_PACKAGES_DEB="python3 python3-pip python3-virtualenv python3-dev"
ANSIBLE_PYTHON_PACKAGES_RPM="python3 python3-pip python3-devel"
ANSIBLE_PYTHON_CMD="python3"
ANSIBLE_PIP_EXTRA_ARGS=""
ANSIBLE_PIP_DEPS_CRYPTO_VERSION="<41"
ANSIBLE_PIP_DEPS_PSYCOPG_PACKAGE="psycopg2-binary"

if [ "$BASE_SYSTEM" == "debian" ]; then
  ANSIBLE_PIP_EXTRA_ARGS="--break-system-packages"
fi


case "$ANSIBLE_VERSION" in

  2.9.*)
    ANSIBLE_PACKAGE_NAME=ansible
    ANSIBLE_PIP_DEPS_CRYPTO_VERSION='==3.*'
    ANSIBLE_LINT_VERSION="4.3.*  rich<11.0.0"
    ANSIBLE_PIP_DEPS_PSYCOPG_PACKAGE="psycopg2"
    ANSIBLE_PIP_EXTRA_ARGS=""
    ;;

  2.1[45].*)
    ANSIBLE_LINT_VERSION="6.*"
    ANSIBLE_PIP_EXTRA_ARGS=""
    ;;

  2.16.*)
    # no release available yet for Rocky with python3 >= 3.10
    if [ "$BASE_SYSTEM" == "redhat" ]; then 
      if grep -q -i --fixed-strings 'VERSION_ID="9.' /etc/os-release; then
        ANSIBLE_PYTHON_PACKAGES_RPM="python3.11 python3.11-pip python3.11-devel"
        shopt -s expand_aliases
        alias python3=/usr/bin/python3.11
      fi
    fi
    ;;

esac

if [ ! -z "$ANSIBLE_LINT_VERSION" ]; then
    ANSIBLE_LINT_VERSION="==$ANSIBLE_LINT_VERSION";
fi

# ansible pip requirements
# => netaddr : ip netmask calculation
# => jmespath : queries in json data
# => pyOpenSSL : deprecated since ansible 2.9, use cryptography instead
# => cryptography==3.* : required for ansible 2.9, 41+ : requires openssl 3
# => PyMySQL[rsa] : mysql
# => psycopg2 : postgreSQL
# 
ANSIBLE_PIP_DEPS="httplib2 six cryptography$ANSIBLE_PIP_DEPS_CRYPTO_VERSION netaddr jmespath PyMySQL[rsa] $ANSIBLE_PIP_DEPS_PSYCOPG_PACKAGE yamllint"


# ansible collections to install
ANSIBLE_COLLECTIONS="ansible.netcommon ansible.utils ansible.posix ansible.windows community.general community.crypto community.mysql community.postgresql"


# ansible user creation and sudo rights
# -p '*' is required to lock the user password while still allowing a login with ssh+key
groupadd --gid ${ANSIBLE_USER_UID} ansible
useradd --uid ${ANSIBLE_USER_UID} --gid ${ANSIBLE_USER_UID} --system  -p '*' --home-dir ${ANSIBLE_HOME_DIR} --create-home --shell /bin/bash  ansible
echo "ansible ALL=NOPASSWD: ALL"  > /etc/sudoers.d/ansible


install --owner ansible --group ansible --mode 0750 -d /etc/ansible
install --owner ansible --group ansible --mode 0755 -d /opt/ansible


# manage python version requirement
# libpq => psycopg2 requirement
# notice : when using another python than the one integrated in the system, change in the  "ansible/inventory/hosts" inventory
# the following information in the ansible group => ansible_python_interpreter: "/path/to/python"

if [ "$BASE_SYSTEM" == "debian" ]; then
    bash wrapper-packages_install.sh \
        ${ANSIBLE_PYTHON_PACKAGES_DEB} \
        libpq-dev

else
    bash wrapper-packages_install.sh \
        ${ANSIBLE_PYTHON_PACKAGES_RPM} \
        postgresql-libs
fi


# extra system packages
bash wrapper-packages_install.sh \
        rsync \
        sshpass \
        gcc \
        whois \
        openssl


# ansible: python module requirements and installation
# ref: https://docs.ansible.com/ansible-core/devel/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pip
# TODO: switch to the ansible user and create a virtualenv
export PIP_ROOT_USER_ACTION=ignore
python3 -m pip install --upgrade --no-cache $ANSIBLE_PIP_EXTRA_ARGS pip wheel
python3 -m pip install --no-cache ${ANSIBLE_PIP_EXTRA_ARGS}  $ANSIBLE_PIP_DEPS
python3 -m pip install --no-cache ${ANSIBLE_PIP_EXTRA_ARGS} "$ANSIBLE_PACKAGE_NAME==$ANSIBLE_VERSION"

python3 -m pip install --no-cache ${ANSIBLE_PIP_EXTRA_ARGS} "ansible-lint${ANSIBLE_LINT_VERSION}"


# ansible: collections installation
for TARGET_COLLECTION in $ANSIBLE_COLLECTIONS; do
	su - ansible -c "ansible-galaxy collection install $TARGET_COLLECTION"
done


# Fix for the docker environment and authorized key - must be last in this script
# A docker volume must also be declared targeting "$ANSIBLE_HOME_DIR/.ssh" to share the key between containers
cat >> $ANSIBLE_HOME_DIR/.bashrc  << 'EOT'
export USER=$( whoami )

if [ ! -z "$ANSIBLE_VAULT_PASS_FILE" ] && [ ! -s "$ANSIBLE_VAULT_PASS_FILE" ]; then
  sudo touch "$ANSIBLE_VAULT_PASS_FILE" && sudo chown ansible: "$ANSIBLE_VAULT_PASS_FILE" && chmod 600 "$ANSIBLE_VAULT_PASS_FILE"
  echo "VAULT PASSKEY CHANGE ME" > "$ANSIBLE_VAULT_PASS_FILE"
fi

if [ ! -d ~/.ssh ]; then
  sudo install --owner ansible --group ansible --mode 700 -d ~/.ssh
else
  sudo chown -R ansible: ~/.ssh
fi
if [ ! -s ~/.ssh/id_rsa ]; then
  ssh-keygen -q -b 4096 -t rsa -f ~/.ssh/id_rsa -N "" -C "ansible@docker-simulator"
  rm ~/.ssh/authorized_keys &>/dev/null
fi
if [ ! -f ~/.ssh/authorized_keys ]; then cp -p  ~/.ssh/id_rsa.pub  ~/.ssh/authorized_keys ; fi

cd /etc/ansible/
EOT

# cleanup
bash wrapper-packages_clean.sh
