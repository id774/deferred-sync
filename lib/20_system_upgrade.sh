# lib/system_upgrade.sh

update_debian_or_ubuntu() {
    apt-get update && \
      apt-get -y upgrade && \
      apt-get autoclean && \
      apt-get -y autoremove
    echo "Return code is $?"
}

update_redhat_or_centos() {
    yum -y --exclude subversion update && \
      yum clean all
    echo "Return code is $?"
    package-cleanup -y --oldkernels
    echo "Return code is $?"
}

upgrade_from_network() {
    test -f /etc/debian_version && update_debian_or_ubuntu
    test -f /etc/redhat-release && update_redhat_or_centos
    which freshclam > /dev/null && freshclam
}

system_upgrade() {
    ping -c 1 debian.org > /dev/null 2>&1 && upgrade_from_network
}

echo "- module system_upgrade loaded"
system_upgrade
