alpha-novel-dl.pl
===============================

アルファポリス投稿小説自動ダウンローダ
-------------------------------

　アルファポリスの投稿小説を青空文庫形式に変換してダウンロード。

### 特徴

- 挿絵対応
- ルビ対応
- 傍点対応
- cp932対応
- 追加分取得機能
- 巡回機能
- マルチスレッド
- Windowsでも動く（多分）

# 導入方法

## 必要ライブラリ

```
    LWP::UserAgent
    HTML::TreeBuilder
    Term::ProgressBar
```

Debain系

`    sudo apt-get install git libwww-perl libhtml-treebuilder-libxml-perl libterm-progressbar-perl ` 

## インストール

`  git clone  https://github.com/yama-natuki/alpha-novel-dl.git `

# 使い方

　落としたい小説の目次ページのurlをコピーしたら、

`    ./alpha-novel-dl.pl 目次のurl  >  保存先ファイル名 `

でファイルに保存される。

　この時挿絵がある場合は、カレントディレクトリに保存される。

# 巡回

　巡回リストを用意すれば自動で巡回してまとめて落とす。

　保存先は指定ディレクト以下にサブディレクトリを自動的に作成して個別に保存される。

　例えば巡回リスト **alpha.lst** で、保存先ベースディレクトリを **~/book** 以下に保存したい場合、

`    ./alpha-novel-dl.pl -c alpha.lst -s ~/book `

とする。

　次回以降は保存した後に追加された部分だけダウンロードする。

## 具体的な使い方

　crontabやタスクスケジューラに一日一回実行で登録し、保存先ディレクトリをクラウドストレージにしておく。  
　あとはクラウドストレージをスマホやタブレットと共有しておけば、
自動的に毎日更新されてスマホの縦書きビューワで読めておいしい。

## 巡回リスト

```
    title = 作品名
    file_name = 保存するファイル名
    url = https://www.alphapolis.co.jp/novel/xxxxxxxxx/xxxxxxxxx
```
　の形式でリストを記述。各レコードは空行で区切る。

　同梱のサンプル参照。

# その他

　一応Windowsでも動作するようにはしてありますが、テストはしていません。___
　今だと **bash_on_ubuntu_on_windows** がWindows10で簡単に導入できるので、
そちらで実行させるのが楽かもしれません。

# ライセンス
　GPLv2

