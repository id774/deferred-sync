#!/bin/sh

setup() {
    if [ -n "$1" ]; then
      test -n "$1" && CONFIG=$1
      test "$1" = "--test" && CONFIG=test/test.conf
    else
      CONFIG=config/sync.conf
      test -f /etc/deferred-sync.conf && \
        CONFIG=/etc/deferred-sync.conf
      test -f /usr/local/etc/deferred_sync.conf && \
        CONFIG=/usr/local/etc/deferred_sync.conf
    fi
    dir_name() { echo ${1%/*}; }
    SCRIPT_HOME=$(cd $(dir_name $0) && pwd)/..
    . $SCRIPT_HOME/$CONFIG
    EXECDIR=${0%/*}
    DATE=`date +%Y%m%d`
}

send_mail_to_admin() {
    nkf -w $JOBLOG | \
      mail -s "[cron-log][`/bin/hostname`] Deferred Sync Log" \
      $ADMIN_MAIL_ADDRESS
}

deferred_sync() {
    echo -n "*** $0: Job start at `/bin/hostname` on ">>$JOBLOG 2>&1
    date "+%Y/%m/%d %T">>$JOBLOG 2>&1
    . $SCRIPT_HOME/bin/loader.sh>>$JOBLOG 2>&1
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
    setup $*
    deferred_sync
}

main $*
