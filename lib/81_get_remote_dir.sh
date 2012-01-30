# lib/get_remote_dir.sh

get_remote_dir() {
    echo -n "* Executing get remote dir on "
    date "+%Y/%m/%d %T"
    OPTS="-avz --delete -e ssh"
    if [ "$DRY_RUN" = "true" ]; then
      OPTS="$OPTS --dry-run"
    fi
    if [ -d $GET_TARGET_DIR ]; then
        echo "rsync $OPTS root@$GET_HOST:$GET_REMOTE_DIR $GET_TARGET_DIR"
        ping -c 1 $GET_HOST > /dev/null 2>&1 && \
          rsync $OPTS root@$GET_HOST:$GET_REMOTE_DIR $GET_TARGET_DIR
        echo "Return code is $?"
    fi
}

echo "- module get_remote_dir loaded"
get_remote_dir
