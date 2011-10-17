# lib/incremental_backup.sh
# $BA}J,%P%C%/%"%C%W$r<hF@$9$k!#(B

purge_expire_dir() {
    while [ $# -gt 0 ]
    do
        BDATE=`echo $1 | sed "s/_backup_//"`
        EXPIREDATE=`date +%Y%m%d -d "$EXPIREDAYS days ago"`
        if [ $BDATE -le $EXPIREDATE ]
        then
            echo "deleting $BACKUPTO/$1"
            rm -rf $BACKUPTO/$1
        fi
        shift
    done
}

purge_expires() {
    echo -n "* Deleting old backup directories on "
    date "+%Y/%m/%d %T"
    purge_expire_dir `ls $BACKUPTO | grep "_backup_"`
}

rsync_options() {
    OPTS="--force --delete-excluded \
      --delete --backup \
      --backup-dir=$BACKUPTO/_backup_$DATE \
      -av"
    if [ -f $EXCLUDEFILE ]; then
        OPTS="$OPTS --exclude-from=$EXCLUDEFILE"
    fi
}

exec_rsync() {
    while [ $# -gt 0 ]
    do
        echo "rsync $OPTS $1 $BACKUPTO"
        rsync $OPTS $1 $BACKUPTO
        echo "Return code is $?"
        shift
    done
}

run_rsync() {
    purge_expires
    rsync_options
    echo -n "* Executing backup with rsync on "
    date "+%Y/%m/%d %T"
    exec_rsync $BACKUPDIRS
}

run_rsync

# $B@bL@=q(B
#
# [$B35MW(B]
# $B%m!<%+%k%[%9%HFb$G!"J]8nBP>]$N%U%!%$%k0l<0$r(B
# $BB`HrMQ$N%G%#%l%/%H%j$K0lC6=8$a$k!#(B
# 
# backup_to_remote $B$rMxMQ$7$FB`Hr$7$?%G%#%l%/%H%j(B
# $B$r%j%b!<%H%[%9%H$KE>Aw$9$k$3$H$GBP>c32@-$r3NJ](B
# $B$9$k$3$H$,$G$-$k!#(B
#
# $B$^$?B`Hr$7$?%G%#%l%/%H%j$r30It%G%#%9%/$K=q$-=P(B
# $B$7$F%P%C%/%"%C%W$H$9$k$3$H$b$G$-$k!#(B
#
# $B$$$:$l$K$;$h(B incremental_backup $B$G$OJ]8nBP>]$N(B
# $B%U%!%$%k$rB`HrMQ$N%G%#%l%/%H%j$K=8$a$?$@$1$J$N(B
# $B$G!"$3$l$KDI2C$7$F2?$i$+$NJ]8n$r$9$kI,MW$,$"$k!#(B
#
# [$B@$Be4IM}(B]
# $BJ]8nBP>]$N%U%!%$%k$O(B rsync $B$N(B --delete $B5!G=$r(B
# $BMxMQ$7$FJQ99$5$l$?%U%!%$%k$N$_B`Hr$9$k!#(B
# $B$^$?$3$N:]!"JQ99A0$N%U%!%$%k$O(B _backup_$BF|IU(B
# $B$H$$$&%G%#%l%/%H%j$KB`Hr$5$l$k!#(B
# $B$3$l$K$h$j@$Be$rAL$C$F%j%9%H%"$9$k$3$H$,2DG=(B
# $B$G$"$k!#(B
#
# [$BBP>]=|30(B]
# backup_exclude $B%U%!%$%k$K=|30$9$k%U%!%$%kL>$r(B
# $BMeNs$9$k$3$H$K$h$j!"%^%C%A$7$?%U%!%$%k$rBP>](B
# $B$+$i=|30$9$k$3$H$,$G$-$k!#(B
#
# $B$?$H$($P(B dot $B$G;O$^$k%G%#%l%/%H%jL>$d!"0l;~(B
# $B%U%!%$%k$NN`$J$I!"J]8n$9$kI,MW$NL5$$%U%!%$%k(B
# $B$r;XDj$9$k$3$H$,$G$-$k!#(B
#
# [$B<B9T>r7o(B]
# SVN $B%@%s%W$d(B MySQL $B%@%s%W$rB`Hr$7$F@$Be4IM}(B
# $B$7$?$$>l9g$O!"$3$l$i$N%b%8%e!<%k$,K\%b%8%e!<%k(B
# $B$h$j@h$K<B9T$5$l$k$h$&$K$9$k$Y$-$G$"$k!#(B
#
# [$B;EMM(B]
# run_rsync $B4X?t(B
# $B@_Dj%U%!%$%k$GDj5A$5$l$?JQ?t(B BACKUPDIRS 
# $B$KDj5A$5$l$?%G%#%l%/%H%jL>$r2r<a$7(B
# exec_rsync $B4X?t$KEO$9!#(B
#
# BACKUPDIRS $B$K$O%G%#%l%/%H%jL>$r%9%Z!<%9$G(B
# $B6h@Z$C$FMeNs$9$k!#$3$3$KDj5A$5$l$?%G%#%l%/%H%j(B
# $B$K$"$k%U%!%$%k$OB`HrMQ$N%G%#%l%/%H%j$K%3%T!<(B
# $B$5$l$k!#$3$l$i$O@$Be4IM}$5$l$k!#(B
# 
# ($BNc(B)
# BACKUPDIRS="/home/myname /etc /var/log"
#
# purge_expires $B4X?t(B
# $B@$Be4IM}$GJ]8n$5$l$?A}J,%P%C%/%"%C%W$N$&$A(B
# EXPIREDAYS $B$KDj5A$5$l$?F|?t0J>e7P2a$7$?(B
# $B%G%#%l%/%H%j$rGK4~$9$k!#(B
# 
# $BNc$($P%9%/%j%W%H$N<B9TF|$,(B 2011/10/30 $B$G(B
# EXPIREDAYS $B$,(B 5 $B$N>l9g(B _backup_20111025 
# $B$h$j8E$$%G%#%l%/%H%j$OGK4~$5$l$k!#(B
#
# purge_expire_dir $B4X?t(B
# $B>e5-$N(B purge_expires $B4X?t$+$i8F$P$l!"(B
# $B<B:]$K%G%#%l%/%H%j$r:o=|$9$k=hM}$r$9$k!#(B
#
# rsync_options $B4X?t(B
# $B:G=*E*$K(B rsync $B$KEO$9%*%W%7%g%s$r@8@.$9$k!#(B
# $BA}J,%P%C%/%"%C%W$NB`HrMQ%G%#%l%/%H%j!"F|IU!"(B
# $B=|30%U%!%$%k$,$3$3$G(B rsync $B$N%*%W%7%g%s$K(B
# $BJQ49$5$l%^!<%8$5$l$k!#(B
#
# exec_rsync $B4X?t(B
# $B@8@.$5$l$?(B rsync $B$N%*%W%7%g%s$r0z?t$K$7$F(B
# $B<B:]$K(B rsync $B$r<B9T$9$k!#(B
#
#
