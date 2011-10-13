#!/bin/sh

setup() {
    dir_name() { echo ${1%/*}; }
    SCRIPT_HOME=$(cd $(dir_name $0) && pwd)
    . $SCRIPT_HOME/../config/sync.conf
    EXECDIR=${0%/*}
    DATE=`date +%Y%m%d`
}

call_func() {
    while [ $# -gt 0 ]
    do
        . $SCRIPT_HOME/../lib/$1.sh
        shift
    done
}

main() {
    setup
    call_func \
      get_resources \
      dump_svn \
      incremental_backup \
      backup_to_remote
}

main
