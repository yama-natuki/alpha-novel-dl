alphapolis2aozora.pl
===============================

alphapolis2aozora.plとは？
-------------------------------

　アルファポリスの投稿小説を青空文庫形式に変換して標準出力に出力するダウンローダ。

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

`    ./alphapolis2aozora.pl 目次のurl  >  保存先ファイル名 `

でファイルに保存される。

　この時挿絵がある場合は、カレントディレクトリに保存される。

# 巡回

　巡回リストを用意すれば自動で巡回してまとめて落とす。

　保存先は指定ディレクト以下にサブディレクトリを自動的に作成して個別に保存される。

　例えば巡回リスト __alpha.lst__ で、保存先ベースディレクトリを __~/book__ 以下に保存したい場合、

`    ./alphapolis2aozora.pl -c alpha.lst -s ~/book `

とする。

　次回以降は保存した後に追加された部分だけダウンロードする。

## 巡回リスト

　リストの形式は同梱のサンプル参照。

# 分割

　ファイルが大きくて分割したい場合は、 [aozora_splitter](https://github.com/yama-natuki/aozora_splitter) を使用。

# ライセンス
　GPLv2

# その他

　名前が長いな………

`    alias a2a="~/git/alphapolis2aozora/alphapolis2aozora.pl " `

とかしてもう __a2a__ でいいんじゃねorz

