#!/bin/sh

setup() {
    dir_name() { echo ${1%/*}; }
    SCRIPT_HOME=$(cd $(dir_name $0) && pwd)
    EXECDIR=${0%/*}

    case $OSTYPE in
      *darwin*)
        OPTIONS=-pPRv
        OWNER=root:wheel
        ;;
      *)
        OPTIONS=-Rvd
        OWNER=root:adm
        ;;
    esac

    test -n "$1" && TARGET=$1
    test -n "$1" || TARGET=/opt/deferred-sync
    test -n "$2" || SUDO=sudo
    test -n "$2" && SUDO=
}

deploy() {
    while [ $# -gt 0 ]
    do
        $SUDO cp $OPTIONS $SCRIPT_HOME/$1 $TARGET/
        shift
    done
}

deploy_to_target() {
    echo "Installing from $SCRIPT_HOME to $TARGET/"
    test -d $TARGET && $SUDO rm -rf $TARGET/
    test -d $TARGET || $SUDO mkdir -p $TARGET/
    deploy bin config lib
}

scheduling() {
    $SUDO cp $OPTIONS $SCRIPT_HOME/cron/deferred-sync \
      /etc/cron.daily/deferred-sync
    test -d /etc/opt/deferred-sync || \
      $SUDO mkdir -p /etc/opt/deferred-sync
    $SUDO cp $OPTIONS $SCRIPT_HOME/config/*.conf \
      /etc/opt/deferred-sync/
    $SUDO chown $OWNER /etc/opt/deferred-sync/*.conf
    $SUDO chmod 640 /etc/opt/deferred-sync/*.conf
    $SUDO rm $TARGET/config/*.conf
    $SUDO ln -s /etc/opt/deferred-sync/sync.conf \
      $TARGET/config/sync.conf
    $SUDO ln -s /etc/opt/deferred-sync/exclude.conf \
      $TARGET/config/exclude.conf
}

logrotate() {
    $SUDO cp $OPTIONS $SCRIPT_HOME/cron/logrotate.d/deferred-sync \
      /etc/logrotate.d/deferred-sync
    $SUDO mkdir -p /var/log/deferred-sync
    $SUDO touch /var/log/deferred-sync/sync.log
    $SUDO chown $OWNER /var/log/deferred-sync/sync.log
    $SUDO chmod 640 /var/log/deferred-sync/sync.log
}

create_backupdir() {
    test -d /home/backup || $SUDO mkdir /home/backup
    $SUDO chown $OWNER /home/backup
    $SUDO chmod 750 /home/backup
    test -d /home/remote || $SUDO mkdir /home/remote
    $SUDO chown $OWNER /home/remote
    $SUDO chmod 750 /home/remote
}

setup_cron() {
    echo "Setting up for cron job"
    scheduling
    logrotate
    create_backupdir
}

set_permission() {
    $SUDO chown -R $OWNER $TARGET
}

installer() {
    setup $*
    deploy_to_target
    test -n "$1" || setup_cron
    test -n "$2" || set_permission
}

installer $*
