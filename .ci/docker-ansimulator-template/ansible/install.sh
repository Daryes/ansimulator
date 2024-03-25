#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# The variables *_VERSION and ANSIBLE_USER_UID come from the docker build argument 
ANSIBLE_HOME_DIR=/home/ansible


ANSIBLE_PACKAGE_NAME=ansible-core
ANSIBLE_PIP_DEPS_CRYPTO_VERSION="<41"
if echo "$ANSIBLE_VERSION" | egrep -q '^2\.9\.'; then
    ANSIBLE_PACKAGE_NAME=ansible
    ANSIBLE_PIP_DEPS_CRYPTO_VERSION='==3.*'
    ANSIBLE_LINT_VERSION="4.3.*  rich<11.0.0"
fi

if [ ! -z "$ANSIBLE_LINT_VERSION" ]; then
    ANSIBLE_LINT_VERSION="==$ANSIBLE_LINT_VERSION";
fi

# ansible pip requirements
# => netaddr : ip netmask calculation
# => jmespath : queries in json data
# => pyOpenSSL : deprecated since ansible 2.9, use cryptography instead
# => cryptography==3.* : required for ansible 2.9, <41 : requires openssl 3
# => cryptography< 41 :  requires openssl 3+
# => PyMySQL[rsa] : mysql
# => psycopg2 : postgreSQL
# 
ANSIBLE_PIP_DEPS="httplib2 six cryptography$ANSIBLE_PIP_DEPS_CRYPTO_VERSION netaddr jmespath PyMySQL[rsa] psycopg2 yamllint"


# ansible collections to install
ANSIBLE_COLLECTIONS="ansible.netcommon ansible.utils ansible.posix community.general community.crypto community.mysql community.postgresql"


# ansible user creation and sudo rights
# -p '*' is required to lock the user password while still allowing a login with ssh+key
groupadd --gid ${ANSIBLE_USER_UID} ansible
useradd --uid ${ANSIBLE_USER_UID} --gid ${ANSIBLE_USER_UID} --system  -p '*' --home-dir ${ANSIBLE_HOME_DIR} --create-home --shell /bin/bash  ansible
echo "ansible ALL=NOPASSWD: ALL"  > /etc/sudoers.d/ansible


install --owner ansible --group ansible --mode 0750 -d /etc/ansible
install --owner ansible --group ansible --mode 0755 -d /opt/ansible


# manage python version requirement
# libpq => psycopg2 requirement
# ansible 2.9 => python 3.5 is the minimum, 3.9 is supported
# ansible 2.15 => python 3.9 minimum
# notice : when using another python than the one integrated in the system, change in the  "ansible/inventory/hosts" inventory
# the following information in the ansible group => ansible_python_interpreter: "/path/to/python"

if [ "$BASE_SYSTEM" == "debian" ]; then
    bash wrapper-packages_install.sh \
        python3 python3-pip python3-virtualenv python3-dev \
        libpq-dev

else
    bash wrapper-packages_install.sh \
        python3 python3-pip python3-devel \
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
python3 -m pip install --upgrade --no-cache pip wheel
python3 -m pip install --no-cache $ANSIBLE_PIP_DEPS
python3 -m pip install --no-cache $ANSIBLE_PACKAGE_NAME==$ANSIBLE_VERSION

python3 -m pip install --no-cache ansible-lint${ANSIBLE_LINT_VERSION}


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

if [ ! -s ~/.ssh/authorized_keys ]; then
  sudo install --owner ansible --group ansible --mode 700 -d ~/.ssh
  sudo chown -R ansible: ~/.ssh
  ssh-keygen -q -b 4096 -t rsa -f ~/.ssh/id_rsa -N "" -C "ansible@docker-simulator"
  cp -p  ~/.ssh/id_rsa.pub  ~/.ssh/authorized_keys
fi
cd /etc/ansible/
EOT

# cleanup
bash wrapper-packages_clean.sh
