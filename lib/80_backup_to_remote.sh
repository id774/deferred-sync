# lib/backup_to_remote.sh

mirror_to_remote() {
    OPTS="-avz --delete -e ssh"
    if [ -n "$DRY_RUN" ]; then
      OPTS="$OPTS --dry-run"
    fi
    #if [ -d $BACKUPTO ]; then
        echo "rsync $OPTS $BACKUPTO root@$1:$2"
        ping -c 1 $1 > /dev/null 2>&1 && \
          rsync $OPTS $BACKUPTO root@$1:$2
        echo "Return code is $?"
    #fi
}

backup_to_remote() {
    echo -n "* Executing backup to remote on "
    date "+%Y/%m/%d %T"
    for REMOTE_HOST in $REMOTE_HOSTS
    do
        mirror_to_remote $REMOTE_HOST $REMOTE_DIR
    done
    unset REMOTE_HOST
}

echo "module backup_to_remote loaded"
backup_to_remote
