# lib/dump_mysql.sh
# MySQL $B%@%s%W$r<hF@$9$k!#(B

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

# $B@bL@=q(B
#
# [$B35MW(B]
# MySQL $B$N%G!<%?%Y!<%9$r%@%s%W$7(B zip $B$G%"!<%+%$%V$9$k!#(B
# mysqldump $B$O>iD9@-$,9b$$$?$a(B zip $B$G05=L$9$k$3$H$G(B
# $BMFNL$r@aLs$9$k!#(B
#
# [$B<B9T>r7o(B]
# backup_to_remote $B$HJ;MQ$9$k>l9g$O$=$N<B9TA0$K(B
# $BK\%b%8%e!<%k$,8F$P$l$k$h$&$K$9$k!#(B
#
# MySQL $B$K@\B3$9$k$?$a$N%f!<%6!<L>$H%Q%9%o!<%I$r(B
# MYSQL_USER $B5Z$S(B MYSQL_PASS $B$KDj5A$9$k!#(B
# $B%G!<%?%Y!<%9$4$H$K%f!<%6!<$H%Q%9%o!<%I$r;H$$(B
# $BJ,$1$k$3$H$O$G$-$J$$!#$7$?$,$C$F%@%s%W$9$k$9$Y$F$N(B
# $B%G!<%?%Y!<%9$r;2>H2DG=$J%f!<%6!<$r;XDj$9$k!#(B
#
# [$B;EMM(B]
# dump_mysql $B4X?t(B
# $B@_Dj%U%!%$%k$GDj5A$5$l$?JQ?t(B MYSQL_DBS $B$NJ8;zNs(B
# $B$KDj5A$5$l$?%G!<%?%Y!<%9L>$r2r<a$7(B
# get_mysqldump $B4X?t$KEO$9!#(B
# 
# ($BNc(B)
# MYSQL_DBS="db_a db_b mysql"
#
# get_mysqldump $B4X?t(B
# $B@_Dj%U%!%$%k$GDj5A$5$l$?JQ?t(B MYSQLDUMP $B$N%G%#%l%/%H%j(B
# $B$K(B MySQL $B%@%s%W$r<hF@$7J]B8$9$k!#(B
#
#
