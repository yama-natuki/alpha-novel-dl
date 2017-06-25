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

# 導入方法

## 必要ライブラリ

```
    LWP::UserAgent
    HTML::TreeBuilder
    File::Basename
```

## インストール

`  git clone  https://github.com/yama-natuki/alphapolis2aozora.git `

# 使い方

　落としたい小説の目次ページのurlをコピーしたら、

`    ./alpha-novel-dl.pl 目次のurl  >  保存先ファイル名 `

でファイルに保存される。

　この時挿絵がある場合は、カレントディレクトリに保存される。

# 巡回

　巡回リストを用意すれば自動で巡回してまとめて落とす。

　保存先は指定ディレクト以下にサブディレクトリを自動的に作成して個別に保存される。

　例えば巡回リスト __alpha.lst__ で、保存先ベースディレクトリを __~/book__ 以下に保存したい場合、

`    ./alpha-novel-dl.pl -c alpha.lst -s ~/book `

とする。

　次回以降は保存した後に追加された部分だけダウンロードする。

## 巡回リスト

```
    title = 作品名
    file_name = 保存するファイル名
    url = https://www.alphapolis.co.jp/novel/xxxxxxxxx/xxxxxxxxx
```
　の形式でリストを記述。各レコードは空行で区切る。

　同梱のサンプル参照。

# ライセンス
　GPLv2

