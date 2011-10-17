mirror_to_remote() {
    if [ -d $BACKUPTO ]; then
        echo "rsync -avz --delete -e ssh $BACKUPTO root@$1:$2"
        ping -c 1 -i 3 $1 > /dev/null 2>&1 && rsync -avz --delete -e ssh $BACKUPTO root@$1:$2
        echo "Return code is $?"
    fi
}

backup_to_remote() {
    echo -n "* Executing backup to remote on "
    date "+%Y/%m/%d %T"
    mirror_to_remote $REMOTE_HOST $REMOTE_DIR
}

backup_to_remote