# lib/get_remote_dir.sh

get_remote() {
    OPTS="-avz --delete -e ssh"
    if [ "$DRY_RUN" = "true" ]; then
      OPTS="$OPTS --dry-run"
    fi
    if [ -d $GET_TARGET_DIR ]; then
        echo "rsync $OPTS root@$GET_HOST:$GET_REMOTE_DIR $GET_TARGET_DIR"
        ping -c 1 $1 > /dev/null 2>&1 && \
          rsync $OPTS root@$GET_HOST:$GET_REMOTE_DIR $GET_TARGET_DIR/$1
        echo "Return code is $?"
    fi
}

get_remote_dir() {
    echo -n "* Executing get remote dir on "
    date "+%Y/%m/%d %T"
    for GET_HOST in $GET_HOSTS
    do
        get_remote $GET_HOST
    done
    unset REMOTE_HOST
}

echo "- module get_remote_dir loaded"
get_remote_dir
