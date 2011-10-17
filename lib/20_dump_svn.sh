# lib/dump_svn.sh
# SVN $B%@%s%W$r<hF@$9$k!#(B

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
    for SVN_REPO in $SVN_REPOS
    do
        get_svndump $SVN_REPO $SVN_PATH/$SVN_REPO
    done
    unset SVN_REPO
}

dump_svn

# $B@bL@=q(B
#
# [$B35MW(B]
# SVN $B$r%@%s%W$7(B zip $B$G%"!<%+%$%V$9$k!#(B
# svndump $B$O>iD9@-$,9b$$$?$a(B zip $B$G05=L$9$k$3$H$G(B
# $BMFNL$r@aLs$9$k!#(B
#
# [$B<B9T>r7o(B]
# backup_to_remote $B$HJ;MQ$9$k>l9g$O$=$N<B9TA0$K(B
# $BK\%b%8%e!<%k$,8F$P$l$k$h$&$K$9$k!#(B
#
# SVNPATH $B$K$O(B SVN $B$N@_Dj%U%!%$%k$GDj5A$5$l$?(B
# SVNParentPath $B$N%Q%9$r;XDj$9$k!#(B
# $B$3$N>l9g%^%k%A%F%J%s%H$G$"$C$F$b(B SVN_REPOS $B$K(B
# $BJ#?t$N%j%]%8%H%jL>$r;XDj$9$k$3$H$G$9$Y$F%@%s%W(B
# $B$9$k$3$H$,2DG=$K$J$k!#(B
#
# [$B;EMM(B]
# dump_svn $B4X?t(B
# $B@_Dj%U%!%$%k$GDj5A$5$l$?JQ?t(B SVN_REPOS $B$NJ8;zNs(B
# $B$KDj5A$5$l$?%[%9%HL>$r2r<a$7(B
# get_svndump $B4X?t$KEO$9!#(B
# SVN_REPOS $B$O(B SVN $B%j%]%8%H%jL>$r;XDj$9$k!#(B
# $B%9%Z!<%9$G6h@Z$C$FJ#?t;XDj$9$k$3$H$,$G$-$k!#(B
# 
# ($BNc(B)
# SVN_REPOS="repoa repob project"
#
# get_svndump $B4X?t(B
# $B@_Dj%U%!%$%k$GDj5A$5$l$?JQ?t(B SVNDUMP $B$N%G%#%l%/%H%j(B
# $B$K(B SVN $B%@%s%W$r<hF@$7J]B8$9$k!#(B
#
#
