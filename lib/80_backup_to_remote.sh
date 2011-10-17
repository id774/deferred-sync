# lib/backup_to_remote.sh
# $B%j%b!<%H%[%9%H$X$N%U%!%$%kE>Aw$r$*$3$J$&(B

mirror_to_remote() {
    if [ -d $BACKUPTO ]; then
        echo "rsync -avz --delete -e ssh $BACKUPTO root@$1:$2"
        ping -c 1 $1 > /dev/null 2>&1 && \
          rsync -avz --delete -e ssh $BACKUPTO root@$1:$2
        echo "Return code is $?"
    fi
}

backup_to_remote() {
    echo -n "* Executing backup to remote on "
    date "+%Y/%m/%d %T"
    for REMOTE_HOST in $REMOTE_HOSTS
    do
        mirror_to_remote $REMOTE_HOST $REMOTE_DIR
    done
    unset REMOTE_HOST
}

backup_to_remote

# $B@bL@=q(B
#
# [$B35MW(B]
# rsync $B$G<+F0E*$KB>$N%[%9%H$XJ]8nBP>]$N%U%!%$%k(B
# $B$rE>Aw$9$k!#%m!<%+%k%[%9%H>c32;~$KB>$N%[%9%H$+(B
# $B$i%G!<%?$rE>Aw$7$F%j%+%P%j$9$k$3$H$,$G$-$k!#(B
#
# $BJ#?t$N5rE@$K%3%T!<$r@8@.$9$k$3$H$b$G$-!"%j%b!<(B
# $B%H%5%$%H$G$O(B sshd $B$@$12TF/$7$F$$$l$PNI$$!#(B
# 
# $B%]!<%HHV9f$J$I(B ssh $B@\B3$K%Q%i%a!<%?$,I,MW$J>l(B
# $B9g$O(B ~/.ssh/config $B$G@_Dj$9$k$3$H$,$G$-$k!#(B
#
# [$B<B9T>r7o(B]
# $BK\%b%8%e!<%k$rMxMQ$9$k$?$a$K$O%m!<%+%k%[%9%H$N(B
# $B%9%/%j%W%H<B9T%f!<%6!<$+$i%j%b!<%H%[%9%H$N(B root 
# $B%f!<%6!<$X$N%Q%9%o!<%IL5$78x3+80G'>Z$,2DG=$G$"(B
# $B$kI,MW$,$"$k!#(B
#
# $B%j%b!<%H%[%9%H$N(B sshd_config $B$K$F0J2<$NCM$r@_Dj(B
# $B$9$k$3$H$r?d>)$9$k!#(B
# PermitRootLogin without-password
# ChallengeResponseAuthentication no
# usePAM no
#
# [$B;EMM(B]
# backup_to_remote $B4X?t(B
# $B@_Dj%U%!%$%k$GDj5A$5$l$?JQ?t(B REMOTE_HOSTS $B$NJ8;zNs(B
# $B$KDj5A$5$l$?%[%9%HL>$r2r<a$7(B
# mirror_to_remote $B4X?t$KEO$9!#(B
# REMOTE_HOSTS $B$O%j%b!<%H%[%9%HL>$r;XDj$9$k!#(B
# $B%9%Z!<%9$G6h@Z$C$FJ#?t;XDj$9$k$3$H$,$G$-$k!#(B
# 
# ($BNc(B)
# REMOTE_HOSTS="hosta hostb 192.168.1.50"
#
# mirror_to_remote $B4X?t(B
# $B@_Dj%U%!%$%k$GDj5A$5$l$?JQ?t(B BACKUPTO $B$N%G%#%l%/%H%j(B
# $B0J2<(B ($B%m!<%+%k$NB`Hr%G%#%l%/%H%j(B) $B$r%j%b!<%H%[%9%H$K(B
# rsync $B$9$k!#(B
# $B:G=i$K%j%b!<%H%[%9%H$K(B ping $B$K$h$k@8;`3NG'$r$7$F!"(B
# $B%j%b!<%H%[%9%H$+$iH?1~$,L5$$>l9g$O%j%?!<%s%3!<%I(B 1 $B$G(B
# $B=*N;$9$k!#(B
#
#
