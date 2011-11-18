# lib/system_upgrade.sh

purge_old_kernels() {
    CURKERNEL=$(uname -r|sed 's/-*[a-z]//g'|sed 's/-386//g')
    LINUXPKG="linux-(image|headers|ubuntu-modules|restricted-modules)"
    METALINUXPKG="linux-(image|headers|restricted-modules)-(generic|i386|server|common|rt|xen)"
    OLDKERNELS=$(dpkg -l|awk '{print $2}'|grep -E $LINUXPKG |grep -vE $METALINUXPKG|grep -v $CURKERNEL)
    apt-get -y purge $OLDKERNELS
}

ubuntu_kernel_upgrade() {
    purge_old_kernels
    apt-get update >> $JOBLOG 2>&1 && \
      apt-get -y install linux-image-$UBUNTU_ARCHITECTURE \
      linux-headers-$UBUNTU_ARCHITECTURE \
      linux-$UBUNTU_ARCHITECTURE
    echo "Return code is $?"
}

system_upgrade() {
    ping -c 1 ubuntu.com > /dev/null 2>&1 && \
      test -n "$UBUNTU_ARCHITECTURE" && \
      test -f /etc/debian_version && \
      test -f /etc/lsb-release && \
      ubuntu_kernel_upgrade
}

echo "- module ubuntu_kernel_upgrade loaded"
system_upgrade