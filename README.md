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

# 分割

　ファイルが大きくて分割したい場合は、 [aozora_splitter](https://github.com/yama-natuki/aozora_splitter) を使用。

# ライセンス
　GPLv2


