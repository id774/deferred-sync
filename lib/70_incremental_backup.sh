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
    for BACKUPDIR in $BACKUPDIRS
    do
        echo "rsync $OPTS $BACKUPDIR $BACKUPTO"
        rsync $OPTS $BACKUPDIR $BACKUPTO
        echo "Return code is $?"
    done
    unset BACKUPDIR
}

run_rsync() {
    purge_expires
    rsync_options
    echo -n "* Executing backup with rsync on "
    date "+%Y/%m/%d %T"
    exec_rsync
}

echo "module run_rsync loaded"
run_rsync
