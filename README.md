alphapolis2aozora.pl
===============================

alphapolis2aozora.plとは？
-------------------------------

　アルファポリスの投稿小説を青空文庫形式に変換して標準出力に出力するダウンローダ。


# 導入方法

## 必要ライブラリ

```
    LWP::UserAgent
    HTML::TreeBuilder;
    File::Basename;
```

## インストール

`  git clone  https://github.com/yama-natuki/alphapolis2aozora.git `

# 使い方

　落としたい小説の目次ページのurlをコピーしたら、

`    ./alphapolis2aozora.pl 目次のurl  >  保存先ファイル名 `

でファイルに保存される。

　この時挿絵がある場合は、カレントディレクトリに保存される。


# ライセンス
　GPLv2


