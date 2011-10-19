# lib/dump_mysql.sh

get_mysqldump() {
    echo "mysqldump $1"
    mysqldump --add-drop-table --add-locks --password=$3 -u $2 \
        $1 > $MYSQLDUMP/mysqldump/$1.sql \
        && zip $MYSQLDUMP/mysqldump/$1.zip $MYSQLDUMP/mysqldump/$1.sql \
        && rm $MYSQLDUMP/mysqldump/$1.sql
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

echo "module dump_mysql loaded"
dump_mysql
