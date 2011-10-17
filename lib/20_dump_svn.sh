get_svndump() {
    echo "svndump $1"
    svnadmin dump $2 > $SVNDUMP/$1.dump \
        && zip $SVNDUMP/$1.zip $SVNDUMP/$1.dump \
        && rm $SVNDUMP/$1.dump
    echo "Return code is $?"
}

dump_svn() {
    echo -n "* Executing svndump on "
    date "+%Y/%m/%d %T"
    get_svndump $REPO_NAME $REPO_DIR
}

dump_svn
