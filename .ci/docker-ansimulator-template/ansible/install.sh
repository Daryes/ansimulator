#!/bin/bash
set -eu

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------
# The variables *_VERSION and ANSIBLE_USER_UID can come from the docker build argument 
ANSIBLE_VERSION=${ANSIBLE_VERSION:-}
ANSIBLE_USER_UID=${ANSIBLE_USER_UID:-421}
ANSIBLE_USER_NAME=${ANSIBLE_USER_NAME:-ansible}

ANSIBLE_HOME_DIR=/home/${ANSIBLE_USER_NAME}

ANSIBLE_PACKAGE_NAME=ansible-core
ANSIBLE_PYTHON_PACKAGES_DEB="python3 python3-pip python3-virtualenv python3-dev"
ANSIBLE_PYTHON_PACKAGES_RPM="python3 python3-pip python3-devel"
ANSIBLE_PYTHON_CMD="python3"
ANSIBLE_PIP_EXTRA_ARGS=""
ANSIBLE_PIP_DEPS_CRYPTO_VERSION="<41"
ANSIBLE_PIP_DEPS_PSYCOPG_PACKAGE="psycopg2-binary"

# List of the required ansible collections
ANSIBLE_REQS_FILE=requirements.yml

# optional components
INSTALL_ANSIBLE_LINT=0
INSTALL_PLAYBOOK_GRAPHER=0
INSTALL_ANSIBLE_NAVIGATOR=0


ANSIBLE_LINT_VERSION=${ANSIBLE_LINT_VERSION:-}
ANSIBLE_LINT_DEPS=""
ANSIBLE_PLAYBOOK_GRAPHER_VERSION=${ANSIBLE_PLAYBOOK_GRAPHER_VERSION:-}
ANSIBLE_NAVIGATOR_VERSION=${ANSIBLE_NAVIGATOR_VERSION:-}


THIS_SCRIPT_DIR="$( dirname $0 )"
# functions ####################################################################

# integrated help
_showUsage() {
    echo -e "Syntax : $( basename $0 ) --base-system redhat|debian  --ansible-version 'x.y'
                                       [--user-uid ${ANSIBLE_USER_UID}]
                                       [--install-ansible-lint]
                                       [--install-ansible-navigator]
                                       [--install-playbook-grapher]
                                       [--debug]
"
}


# main #########################################################################

# command line parameters
if [ $# -eq 0 ]; then _showUsage; exit 1; fi

while [ $# -gt 0 ]; do
    arg="$1"
    # support for both -param and --param syntax
    if echo "$arg" | egrep -q '^--[a-z]+'; then arg="${arg:1}"; fi

    case $arg in
        -help)
            _showUsage
            exit 0
            ;;

        -debug)
            set -eux
            ;;

        -base-system)
            BASE_SYSTEM=$2
            shift
            ;;

        -ansible-version)
            ANSIBLE_VERSION=$2
            shift
            ;;

        -user-uid)
            ANSIBLE_USER_UID=$2
            shift
            ;;

        -install-ansible-lint)
            INSTALL_ANSIBLE_LINT=1
            ;;

        -install-ansible-navigator)
            INSTALL_ANSIBLE_NAVIGATOR=1
            ;;

        -install-playbook-grapher)
            INSTALL_PLAYBOOK_GRAPHER=1
            ;;


        # inconnu
        *)
            echo "Unknown argument : $arg"
            _showUsage
            exit 1
            ;;

        esac

    #  argument suivant
    [ $# -gt 0 ] && shift
done


case "$ANSIBLE_VERSION" in

  2.9.*)
    ANSIBLE_PACKAGE_NAME=ansible
    ANSIBLE_PIP_DEPS_CRYPTO_VERSION='==3.*'
    ANSIBLE_PIP_DEPS_PSYCOPG_PACKAGE="psycopg2"
    ANSIBLE_PIP_EXTRA_ARGS=""
    ANSIBLE_REQS_FILE=requirements_2.9.yml
    ANSIBLE_LINT_VERSION="4.3.*"
    ANSIBLE_LINT_DEPS="rich<11.0.0"
    ANSIBLE_PLAYBOOK_GRAPHER_VERSION="1.0.0.dev4"
    INSTALL_ANSIBLE_NAVIGATOR=0  # not supported with 2.9
    ;;

  2.1[45].*)
    ANSIBLE_PIP_EXTRA_ARGS=""
    ANSIBLE_REQS_FILE=requirements_2.16.yml
    ANSIBLE_LINT_VERSION="6.*"
    ANSIBLE_PLAYBOOK_GRAPHER_VERSION="2.0.0"
    ;;

  # order is important - must be before 2.16+
  2.1[6789].*)
    # no release available yet for Rocky with native python3 > 3.9
    if [ "$BASE_SYSTEM" == "redhat" ]; then 
        if grep -q -i --fixed-strings 'VERSION_ID="9.' /etc/os-release; then
            ANSIBLE_PYTHON_PACKAGES_RPM="python3.11 python3.11-pip python3.11-devel"
            shopt -s expand_aliases
            alias python3=/usr/bin/python3.11
        fi
    fi
    ;;&  # contiue to the next version

  2.16.*)
    ANSIBLE_REQS_FILE=requirements_2.16.yml
    ;;

esac


# ansible pip requirements
# => netaddr : ip netmask calculation
# => jmespath : queries in json data
# => pyOpenSSL : deprecated since ansible 2.9, use cryptography instead
# => cryptography==3.* : required for ansible 2.9, 41+ : requires openssl 3
# => PyMySQL[rsa] : mysql
# => psycopg2 : postgreSQL
# 
ANSIBLE_PIP_DEPS="httplib2 six cryptography$ANSIBLE_PIP_DEPS_CRYPTO_VERSION netaddr jmespath PyMySQL[rsa] $ANSIBLE_PIP_DEPS_PSYCOPG_PACKAGE yamllint"

# The ansible collections are loaded from the requirements.yml file


# ansible user creation and sudo rights
# -p '*' is required to lock the user password while still allowing a login with ssh+key
groupadd --gid ${ANSIBLE_USER_UID} ${ANSIBLE_USER_NAME}
useradd --uid ${ANSIBLE_USER_UID} --gid ${ANSIBLE_USER_UID} --system  -p '*' --home-dir ${ANSIBLE_HOME_DIR} --create-home --shell /bin/bash  ${ANSIBLE_USER_NAME}
echo "${ANSIBLE_USER_NAME} ALL=NOPASSWD: ALL"  > /etc/sudoers.d/ansible


install --owner ${ANSIBLE_USER_NAME} --group ${ANSIBLE_USER_NAME} --mode 0750 -d /etc/ansible
install --owner ${ANSIBLE_USER_NAME} --group ${ANSIBLE_USER_NAME} --mode 0755 -d /opt/ansible


# manage python version requirement
# libpq (debian) / postgresql-libs (redhat) => psycopg2 requirement
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

# debian specific
if [ "$BASE_SYSTEM" == "debian" ] && python3 -m pip install --help |grep -q --fixed-strings -- "break-system-packages" ; then
  # the parameter is not always supported depending of the system version
  ANSIBLE_PIP_EXTRA_ARGS="${ANSIBLE_PIP_EXTRA_ARGS} --break-system-packages"
fi


export PIP_ROOT_USER_ACTION=ignore
python3 -m pip install --upgrade --no-cache $ANSIBLE_PIP_EXTRA_ARGS pip wheel
python3 -m pip install --no-cache ${ANSIBLE_PIP_EXTRA_ARGS}  $ANSIBLE_PIP_DEPS
python3 -m pip install --no-cache ${ANSIBLE_PIP_EXTRA_ARGS} "$ANSIBLE_PACKAGE_NAME==$ANSIBLE_VERSION"


# ansible: collections installation - provided by the requirements file
su - ${ANSIBLE_USER_NAME} -c "ansible-galaxy collection install -r ${THIS_SCRIPT_DIR}/${ANSIBLE_REQS_FILE}"


# Fix for the docker environment and authorized key - must be last in this script
# A docker volume must also be declared targeting "$ANSIBLE_HOME_DIR/.ssh" to share the key between containers
cat >> $ANSIBLE_HOME_DIR/.bashrc  << 'EOT'
export USER=$( whoami )

if [ ! -z "$ANSIBLE_VAULT_PASSWORD_FILE" ] && [ ! -s "$ANSIBLE_VAULT_PASSWORD_FILE" ]; then
  sudo install --owner $USER --group $USER --mode 600 -T /dev/null "$ANSIBLE_VAULT_PASSWORD_FILE"
  echo "VAULT PASSKEY CHANGE ME" > "$ANSIBLE_VAULT_PASSWORD_FILE"
fi

if [ ! -d ~/.ssh ]; then
  sudo nstall --owner $USER --group $USER --mode 700 -d ~/.ssh
else
  sudo chown -R $USER: ~/.ssh
fi
if [ ! -s ~/.ssh/id_rsa ]; then
  ssh-keygen -q -b 4096 -t rsa -f ~/.ssh/id_rsa -N "" -C "ansible@docker-simulator"
  rm ~/.ssh/authorized_keys &>/dev/null
fi
if [ ! -f ~/.ssh/authorized_keys ]; then cp -p  ~/.ssh/id_rsa.pub  ~/.ssh/authorized_keys ; fi

cd /etc/ansible/
EOT


# ansible-lint ################################################################

if [ $INSTALL_ANSIBLE_LINT -eq 1 ]; then
    echo ""
    echo "Installing ansible-lint ..."

    if [ ! -z "$ANSIBLE_LINT_VERSION" ]; then ANSIBLE_LINT_VERSION="==$ANSIBLE_LINT_VERSION"; fi

    export PIP_ROOT_USER_ACTION=ignore
    python3 -m pip install --no-cache ${ANSIBLE_PIP_EXTRA_ARGS} "ansible-lint${ANSIBLE_LINT_VERSION}" $ANSIBLE_LINT_DEPS
fi


# ansible-navigator ###########################################################

if [ $INSTALL_ANSIBLE_NAVIGATOR -eq 1 ]; then
    echo ""
    echo "Installing ansible-navigator ..."

    if [ ! -z "$ANSIBLE_NAVIGATOR_VERSION" ]; then ANSIBLE_NAVIGATOR_VERSION="==$ANSIBLE_NAVIGATOR_VERSION"; fi

    export PIP_ROOT_USER_ACTION=ignore
    python3 -m pip install --no-cache ${ANSIBLE_PIP_EXTRA_ARGS} "ansible-navigator[ansible-core]${ANSIBLE_NAVIGATOR_VERSION}"
fi


# playbook-grapher ###########################################################

if [ $INSTALL_PLAYBOOK_GRAPHER -eq 1 ]; then
    echo ""
    echo "Installing playbook-grapher ..."

    if [ ! -z "$ANSIBLE_PLAYBOOK_GRAPHER_VERSION" ]; then ANSIBLE_PLAYBOOK_GRAPHER_VERSION="==$ANSIBLE_PLAYBOOK_GRAPHER_VERSION"; fi

    # requirement
    bash wrapper-packages_install.sh \
        graphviz

    # ansible: python requirements and installation
    export PIP_ROOT_USER_ACTION=ignore
    python3 -m pip install --upgrade --no-cache ${ANSIBLE_PIP_EXTRA_ARGS} ansible-playbook-grapher$ANSIBLE_PLAYBOOK_GRAPHER_VERSION
fi


# cleanup
bash wrapper-packages_clean.sh
