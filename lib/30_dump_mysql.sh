get_mysqldump() {
    echo "mysqldump $1"
    mysqldump --add-drop-table --add-locks --password=$3 -u $2 \
        $1 > $BACKUPTO/mysqldump/$1.sql \
        && zip $BACKUPTO/mysqldump/$1.zip $BACKUPTO/mysqldump/$1.sql \
        && rm $BACKUPTO/mysqldump/$1.sql
    echo "Return code is $?"
}

dump_mysql() {
    echo -n "* Executing mysqldump on "
    date "+%Y/%m/%d %T"
    for MYSQL_TABLE in $MYSQL_TABLES
    do
        get_mysqldump $MYSQL_TABLE $MYSQL_USER $MYSQL_PASS
    done
    unset MYSQL_TABLE
}


load_modules_all() {
    for MODULE in $SCRIPT_HOME/../lib/*.sh
    do
        . $MODULE
    done
    unset MODULE
}

dump_mysql
