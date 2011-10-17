# lib/dump_svn.sh
# SVN ダンプを取得する。

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

# 説明書
#
# [概要]
# SVN をダンプし zip でアーカイブする。
# svndump は冗長性が高いため zip で圧縮することで
# 容量を節約する。
#
# [実行条件]
# backup_to_remote と併用する場合はその実行前に
# 本モジュールが呼ばれるようにする。
#
# SVNPATH には SVN の設定ファイルで定義された
# SVNParentPath のパスを指定する。
# この場合マルチテナントであっても SVN_REPOS に
# 複数のリポジトリ名を指定することですべてダンプ
# することが可能になる。
#
# [仕様]
# dump_svn 関数
# 設定ファイルで定義された変数 SVN_REPOS の文字列
# に定義されたホスト名を解釈し
# get_svndump 関数に渡す。
# SVN_REPOS は SVN リポジトリ名を指定する。
# スペースで区切って複数指定することができる。
# 
# (例)
# SVN_REPOS="repoa repob project"
#
# get_svndump 関数
# 設定ファイルで定義された変数 SVNDUMP のディレクトリ
# に SVN ダンプを取得し保存する。
#
#
