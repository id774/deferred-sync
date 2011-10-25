# lib/dump_mysql.sh

get_mysqldump() {
    echo "mysqldump $1"
    test -f $MYSQLDUMP/$1.zip && \
      rm $MYSQLDUMP/$1.zip
    mysqldump --add-drop-table --add-locks --password=$3 -u $2 \
        $1 > $MYSQLDUMP/$1.sql \
        && zip $MYSQLDUMP/$1.zip $MYSQLDUMP/$1.sql \
        && rm $MYSQLDUMP/$1.sql
    echo "Return code is $?"
}

dump_mysql() {
    echo -n "* Executing mysqldump on "
    date "+%Y/%m/%d %T"
    for MYSQL_DB in $MYSQL_DBS
    do
        get_mysqldump $MYSQL_DB $MYSQL_USER $MYSQL_PASS
    done
    unset MYSQL_DB
}

echo "- module dump_mysql loaded"
dump_mysql
