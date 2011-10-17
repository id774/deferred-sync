# lib/backup_to_remote.sh
# リモートホストへのファイル転送をおこなう

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

# 説明書
#
# [概要]
# rsync で自動的に他のホストへ保護対象のファイル
# を転送する。ローカルホスト障害時に他のホストか
# らデータを転送してリカバリすることができる。
#
# 複数の拠点にコピーを生成することもでき、リモー
# トサイトでは sshd だけ稼働していれば良い。
# 
# ポート番号など ssh 接続にパラメータが必要な場
# 合は ~/.ssh/config で設定することができる。
#
# [実行条件]
# 本モジュールを利用するためにはローカルホストの
# スクリプト実行ユーザーからリモートホストの root 
# ユーザーへのパスワード無し公開鍵認証が可能であ
# る必要がある。
#
# リモートホストの sshd_config にて以下の値を設定
# することを推奨する。
# PermitRootLogin without-password
# ChallengeResponseAuthentication no
# usePAM no
#
# [仕様]
# backup_to_remote 関数
# 設定ファイルで定義された変数 REMOTE_HOSTS の文字列
# に定義されたホスト名を解釈し
# mirror_to_remote 関数に渡す。
# REMOTE_HOSTS はリモートホスト名を指定する。
# スペースで区切って複数指定することができる。
# 
# (例)
# REMOTE_HOSTS="hosta hostb 192.168.1.50"
#
# mirror_to_remote 関数
# 設定ファイルで定義された変数 BACKUPTO のディレクトリ
# 以下 (ローカルの退避ディレクトリ) をリモートホストに
# rsync する。
# 最初にリモートホストに ping による生死確認をして、
# リモートホストから反応が無い場合はリターンコード 1 で
# 終了する。
#
#
