# lib/incremental_backup.sh
# 増分バックアップを取得する。

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

# 説明書
#
# [概要]
# ローカルホスト内で、保護対象のファイル一式を
# 退避用のディレクトリに一旦集める。
# 
# backup_to_remote を利用して退避したディレクトリ
# をリモートホストに転送することで対障害性を確保
# することができる。
#
# また退避したディレクトリを外部ディスクに書き出
# してバックアップとすることもできる。
#
# いずれにせよ incremental_backup では保護対象の
# ファイルを退避用のディレクトリに集めただけなの
# で、これに追加して何らかの保護をする必要がある。
#
# [世代管理]
# 保護対象のファイルは rsync の --delete 機能を
# 利用して変更されたファイルのみ退避する。
# またこの際、変更前のファイルは _backup_日付
# というディレクトリに退避される。
# これにより世代を遡ってリストアすることが可能
# である。
#
# [対象除外]
# backup_exclude ファイルに除外するファイル名を
# 羅列することにより、マッチしたファイルを対象
# から除外することができる。
#
# たとえば dot で始まるディレクトリ名や、一時
# ファイルの類など、保護する必要の無いファイル
# を指定することができる。
#
# [実行条件]
# SVN ダンプや MySQL ダンプを退避して世代管理
# したい場合は、これらのモジュールが本モジュール
# より先に実行されるようにするべきである。
#
# [仕様]
# run_rsync 関数
# 設定ファイルで定義された変数 BACKUPDIRS 
# に定義されたディレクトリ名を解釈し
# exec_rsync 関数に渡す。
#
# BACKUPDIRS にはディレクトリ名をスペースで
# 区切って羅列する。ここに定義されたディレクトリ
# にあるファイルは退避用のディレクトリにコピー
# される。これらは世代管理される。
# 
# (例)
# BACKUPDIRS="/home/myname /etc /var/log"
#
# purge_expires 関数
# 世代管理で保護された増分バックアップのうち
# EXPIREDAYS に定義された日数以上経過した
# ディレクトリを破棄する。
# 
# 例えばスクリプトの実行日が 2011/10/30 で
# EXPIREDAYS が 5 の場合 _backup_20111025 
# より古いディレクトリは破棄される。
#
# purge_expire_dir 関数
# 上記の purge_expires 関数から呼ばれ、
# 実際にディレクトリを削除する処理をする。
#
# rsync_options 関数
# 最終的に rsync に渡すオプションを生成する。
# 増分バックアップの退避用ディレクトリ、日付、
# 除外ファイルがここで rsync のオプションに
# 変換されマージされる。
#
# exec_rsync 関数
# 生成された rsync のオプションを引数にして
# 実際に rsync を実行する。
#
#
