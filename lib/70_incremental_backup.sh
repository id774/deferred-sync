# lib/incremental_backup.sh

purge_expire_dir() {
    while [ $# -gt 0 ]
    do
        BDATE=`echo $1 | sed "s/_backup_//"`
        EXPIREDATE=`date +%Y%m%d -d "$EXPIREDAYS days ago"`
        if [ $BDATE -le $EXPIREDATE ]
        then
            echo "deleting $BACKUPTO/$1"
            rm -rf $BACKUPTO/$1
        fi
        shift
    done
}

purge_expires() {
    echo -n "* Deleting old backup directories on "
    date "+%Y/%m/%d %T"
    purge_expire_dir `ls $BACKUPTO | grep "_backup_"`
}

rsync_options() {
    OPTS="--force --delete-excluded \
      --delete --backup \
      --backup-dir=$BACKUPTO/_backup_$DATE \
      -av"
    if [ -f $EXCLUDEFILE ]; then
        OPTS="$OPTS --exclude-from=$EXCLUDEFILE"
    fi
    if [ -n "$DRY_RUN" ]; then
      OPTS="$OPTS --dry-run"
    fi
}

exec_rsync() {
    while [ $# -gt 0 ]
    do
        echo "rsync $OPTS $1 $BACKUPTO"
        rsync $OPTS $1 $BACKUPTO
        echo "Return code is $?"
        shift
    done
}

run_rsync() {
    purge_expires
    rsync_options
    echo -n "* Executing backup with rsync on "
    date "+%Y/%m/%d %T"
    exec_rsync $BACKUPDIRS
}

run_rsync
