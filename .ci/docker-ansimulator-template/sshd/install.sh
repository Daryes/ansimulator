#!/bin/bash
set -eux

# change to current script dir
cd $( dirname $0 )
# -----------------------------------------------------------------------------

# Some names are not the same depending of the distrib
PACKAGE_CLIENT=openssh-client
command -v yum &>/dev/null && PACKAGE_CLIENT=openssh-clients


# install packages
bash wrapper-packages_install.sh \
        openssh-server \
        $PACKAGE_CLIENT


# cleanup
bash wrapper-packages_clean.sh


# generate the host keys
ssh-keygen -A


# sshd fixes when running in a container
rm /etc/nologin /var/run/nologin 2>/dev/null || true
install --owner root --group root --mode 755 -d /run/sshd
sed -i '/^session .* pam_loginuid.so/ s/required/optional/' /etc/pam.d/sshd
# shouldn't be used: sed -i "/^UsePAM .*/ s/ yes/ no/" /etc/ssh/sshd_config


echo '
To activate opensshd, the image requires these additionnal requirements:
  * init: ENTRYPOINT [ "/usr/sbin/sshd", "-De" ]
  * port declaration: EXPOSE 22
'
