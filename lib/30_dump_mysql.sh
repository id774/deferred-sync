# lib/dump_mysql.sh
# MySQL ダンプを取得する。

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

dump_mysql

# 説明書
#
# [概要]
# MySQL のデータベースをダンプし zip でアーカイブする。
# mysqldump は冗長性が高いため zip で圧縮することで
# 容量を節約する。
#
# [実行条件]
# backup_to_remote と併用する場合はその実行前に
# 本モジュールが呼ばれるようにする。
#
# MySQL に接続するためのユーザー名とパスワードを
# MYSQL_USER 及び MYSQL_PASS に定義する。
# データベースごとにユーザーとパスワードを使い
# 分けることはできない。したがってダンプするすべての
# データベースを参照可能なユーザーを指定する。
#
# [仕様]
# dump_mysql 関数
# 設定ファイルで定義された変数 MYSQL_DBS の文字列
# に定義されたデータベース名を解釈し
# get_mysqldump 関数に渡す。
# 
# (例)
# MYSQL_DBS="db_a db_b mysql"
#
# get_mysqldump 関数
# 設定ファイルで定義された変数 MYSQLDUMP のディレクトリ
# に MySQL ダンプを取得し保存する。
#
#
