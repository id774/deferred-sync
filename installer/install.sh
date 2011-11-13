#!/bin/sh

setup() {
    dir_name() { echo ${1%/*}; }
    SCRIPT_HOME=$(cd $(dir_name $0) && pwd)/..
    EXECDIR=${0%/*}

    case $OSTYPE in
      *darwin*)
        OPTIONS=-pPRv
        OWNER=root:wheel
        ;;
      *)
        OPTIONS=-Rvd
        OWNER=root:root
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
    deploy bin config etc lib
}

set_permission() {
    $SUDO chown -R $OWNER $TARGET
}

installer() {
    setup $*
    deploy_to_target
    test -n "$2" || set_permission
}

installer $*
