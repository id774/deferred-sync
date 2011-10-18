#!/bin/sh

setup() {
    CONFIG=sync.conf
    dir_name() { echo ${1%/*}; }
    SCRIPT_HOME=$(cd $(dir_name $0) && pwd)
    . $SCRIPT_HOME/../config/$CONFIG
    EXECDIR=${0%/*}
    DATE=`date +%Y%m%d`
    #JOBLOG=/var/log/sysadmin/sync.log
    JOBLOG=$SCRIPT_HOME/../log/sync.log
    #ADMIN_MAIL_ADDRESS=xxxxxx@gmail.com
}

send_mail_to_admin() {
    nkf -w $JOBLOG | \
      mail -s "[cron-log][`/bin/hostname`] Deferred Sync Log" $ADMIN_MAIL_ADDRESS
}

deferred_sync() {
    echo -n "*** $0: Job start at `/bin/hostname` on ">>$JOBLOG 2>&1
    date "+%Y/%m/%d %T">>$JOBLOG 2>&1
    . $SCRIPT_HOME/loader.sh>>$JOBLOG 2>&1
    echo -n "*** $0: End of Job at `/bin/hostname` on ">>$JOBLOG 2>&1
    date "+%Y/%m/%d %T">>$JOBLOG 2>&1
    echo>>$JOBLOG 2>&1
    case "$ADMIN_MAIL_ADDRESS" in
      *@*)
        send_mail_to_admin
        ;;
    esac
}

main() {
    setup
    deferred_sync
}

main
