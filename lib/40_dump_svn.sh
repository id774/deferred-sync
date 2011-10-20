# lib/dump_svn.sh

get_svndump() {
    echo "svndump $1"
    test -f $SVNDUMP/$1.zip && \
      rm $SVNDUMP/$1.zip
    svnadmin dump $2 > $SVNDUMP/$1.dump \
        && zip $SVNDUMP/$1.zip $SVNDUMP/$1.dump \
        && rm $SVNDUMP/$1.dump
    echo "Return code is $?"
}

dump_svn() {
    echo -n "* Executing svndump on "
    date "+%Y/%m/%d %T"
    for SVN_REPO in $SVN_REPOS
    do
        get_svndump $SVN_REPO $SVN_PATH/$SVN_REPO
    done
    unset SVN_REPO
}

echo "- module dump_svn loaded"
dump_svn