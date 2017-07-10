#!/usr/bin/perl
#
# アルファポリスの投稿小説を青空文庫形式にしてダウンロードする。
# Copyright (c) 2017 ◆.nITGbUipI
# license GPLv2
#
# Usage.
# ./alpha-novel-dl.pl 目次url > 保存先ファイル名
#
# としてリダイレクトすれば青空文庫形式で保存される。
#
# 特徴
# ・挿絵対応
#     カレントディレクトリに保存さる。
# ・ルビ対応
# ・傍点対応
# ・cp932対応
#     utf8 な環境でしかテストしていない。
#     一応WinではShift_JISで出力するようにはしている。
# ・巡回機能
#
# 変更履歴
# 2017年06月21日(水曜日) 16:55:46 JST
# アルファポリスのサイトリニューアルに伴い、取得できるように書き換えた。
# 2017年06月23日(金曜日) 12:12:01 JST
# 追加されたエピソードだけ取得をする機能を追加。
#    -u YY.MM.DD の形式で日付を指定すれば、その日付以降だけをダウンロードする。
# 2017年06月24日(土曜日) 15:30:42 JST
# 巡回機能を追加。
# 巡回リストを指定すると自動で巡回してくれる。
# 
#     alpha-novel-dl.pl -c check.lst -s ~/Desktop
# と指定するとcheck.lstを読み込んで、~/Desktop/以下に個別Dirを作成して保存してくれる。
# リスト形式はサンプルを参照。
# 2017年06月25日(日曜日) 13:59:36 JST
# 巡回機能で追加分だけダウンロードするようにした。
# 初回何もなければ全部ダウンロードし、次回からはダウンロードした後に
# 追加された分だけダウンロードする。
# 2017年06月27日(火曜日) 15:00:10 JST
# レンタルにされた部分はスルーするようにした。
# おかげでやる気減退。
# 2017年06月30日(金曜日) 17:10:32 JST
# テスト実行モードを実装。
# --dry-run または -n オプションを付けると実際に書き込みはしないで実行する。
# 2017年07月10日(月曜日) 11:37:49 JST
# マルチスレッド導入。
#

use strict;
use warnings;
use LWP::UserAgent;
use HTML::TreeBuilder;
use utf8;
use Encode;
use File::Basename;
use Time::Local 'timelocal';
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use Cwd;
use File::Spec;
use threads;
use Thread::Queue;
use Thread::Semaphore;
use Term::ProgressBar;

my $url_prefix = "https://www.alphapolis.co.jp";
my $user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0';
my $separator = "▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n";
my $kaipage = "［＃改ページ］\n";
my ($main_title, $author );
my $chapter_title;
my ($dryrun, $chklist, $savedir, $split_size, $update, $show_help );
my $last_date;  #前回までの取得日
my $base_path;  #保存先dir
my $semaphore = Thread::Semaphore->new(8); #スレッド最大値。
my $charcode = 'UTF-8';

if ($^O =~ m/MSWin32/) {
    $charcode = "cp932";
}

sub get_contents {
    my $address = shift;
    my $http = LWP::UserAgent->new;
    $http->agent($user_agent);
    my $res = $http->get($address);
    my $content = $res->content;
    return $content;
}

# htmlパース
sub html2tree {
    my $item = shift;
    my $tree = HTML::TreeBuilder->new;
    $tree->no_space_compacting;
    $tree->parse($item);
    return $tree;
    $tree->delete;
}

# 目次作成
sub get_index {
    my $item = shift;
    my $url_list = [];          # リファレンス初期化
    my $count = 0;
    $item = &html2tree($item);
    my $mokuji = $item->look_down('class', 'table-of-contents novels')
                      ->look_down('class', "episodes");
    foreach my $tag ($mokuji->look_down('class', "episode")) {
        my $url = $tag->find('a')->attr('href');            # url
        my $title = $tag->look_down('class', 'title')->as_text; # title
        utf8::decode($title);
        $url = $url_prefix . $url;
        my $open_date = $tag->look_down('class', 'open-date')->as_text;
        $open_date =~ s|(\d{4}\.\d{2}\.\d{2}) \d.+|$1|;
        $open_date = &epochtime( $open_date );
        $url_list->[$count] = [$title, $url, $open_date]; # タイトル、url、公開日
        $count++;
    }

    if ($update) {
        my @reverse = reverse( @$url_list );
        my @up_list = ();
        for (my $i = 0; $reverse[$i]->[2] > $last_date; $i++) {
            push(@up_list, $reverse[$i]);
        }
        @up_list = reverse( @up_list );
        $url_list = \@up_list;
    }
    return $url_list;
}

# 作品名、著者名取得
sub header {
    my $item = shift;
    $item = &html2tree( $item );
    $item = $item->look_down( 'class', 'content-main');
    $main_title = $item->look_down( 'class', 'title')->as_text;
    $author = $item->look_down( 'class', 'author')->find('a')->as_text;
    utf8::decode($main_title);
    utf8::decode($author);
    return sprintf("%s", $main_title . "\n" . $author . "\n\n\n");
}

# 本文処理
sub honbun {
    my $item = shift;
    utf8::decode($item);
    $item =~  s|\x0D\x0A|\n|g;  #改行コード変換。
    # 章見出し取得
    $item =~  m|<div class="chapter-title">(.+?)</div>|s;
    $chapter_title =  $1;
    $chapter_title =~ s|\t||g;
    $chapter_title =~ s|\n||g;
    # 本文取得
    $item =~  m|.*<div class="text " id="novelBoby">(.+)</div>.+<a href="/Users/login.+|s;
    $item =   $1;
    $item =~  s|<br />||g;
    $item =~  s|&nbsp;| |g;
    $item =~  s|\t\t||;         # 一行目のタブを削除。
    $item =~  s|<ruby>(.+?)<rt>(.+?)</rt></ruby>|｜$1《$2》|g;
    $item =~  s|<em>(.+?)</em>|［＃傍点］$1［＃傍点終わり］|g;
    $item =~  s|</?span>||g;
    $item =~  s|！！|!!|g;
    $item =~  s|！？|!\?|g;
    $item =~ tr|\x{ff5e}|\x{301c}|; #全角チルダ->波ダッシュ
    # 挿絵処理
    if ( $item =~ m|story-image| ) {
        $item =~  s|<a href=.+? class="story-image"><img src="(.+?)" alt=""/></a>|&get_pic($1)|eg;
    }
    return $item;
}

# 挿絵保存
sub get_pic {
    my $address = shift;
    my $fname = basename( $address );
    unless ( defined($base_path) ) {
        $fname = basename( $address );
    }
    else {
        $fname = &get_path($base_path, $fname);
    }
    my $http = LWP::UserAgent->new;
    $http->agent($user_agent);
    my $res = $http->get( $address, ':content_file' => $fname );
    if ( $res->is_success ) {
        print STDERR encode($charcode, "\033[1G\033[0Ksave:: $fname\n");
    }
    else {
        print STDERR encode($charcode, "\033[1G\033[0Kerror:: $fname\n");
    }
    # 挿絵リンク処理
    return "［＃挿絵" .
        "（" .
        File::Basename::basename( $address ) .
            "）入る］\n";
}

sub get_all {
    my $index = shift;
    my $count = scalar(@$index);
    my @ring;
    my $queue = new Thread::Queue;

    # キュー追加
    foreach (@$index){
        $queue->enqueue($_);
    }

    my $prog = Term::ProgressBar->new( {count => $count, name => "Download"} );

    foreach (1..$count) {
        $prog->update($_);
        $semaphore->down;
         my $thread = threads->create(
              sub {
                  while (my $sec = $queue->dequeue ) {
                      my $text = &get_contents( $sec->[1] );
                      $text = &honbun( $text );
                      my $title = $sec->[0];
                      my $time = &timeepoc( $sec->[2] );
                      my $item = &honbun_formater( $text, $title );
                      $semaphore->up;
                      return [ $title, $item, $time ];
                  }
              });
        push(@ring, $thread );
        $queue->enqueue(undef);
    }

    foreach my $x (@ring) {
        my ($ret) = $x->join;
        my $title = $ret->[0];
        my $item  = $ret->[1];
        my $time  = $ret->[2];
        print STDERR encode($charcode, "success:: $time : $title \n");
        print encode($charcode, $item);
    }

}

sub honbun_formater  {
    my ($text, $title) = @_;
    my $item;
    my $midasi = "\n［＃中見出し］" . $title . "［＃中見出し終わり］\n\n\n";
    if ( $chapter_title ne "" ) {
        $chapter_title = "\n" . $chapter_title . "\n";
        $item = $kaipage . $separator .
            $chapter_title .
            $midasi . $text . "\n\n" . $separator;
    }
    else {
        $item = $kaipage . $separator .
            $midasi . $text . "\n\n" . $separator;
    }
    return $item;
}

#コマンドラインの取得
sub getopt() {
    GetOptions(
               "chklist|c=s" => \$chklist,
               "savedir|s=s" => \$savedir,
               "update|u=s"  => \$update,
               "dry-run|n"   => \$dryrun,
               "help|h"      => \$show_help
              );
}

sub help {
  print STDERR encode($charcode,
        "alpha-novel-dl.pl  (c) 2017 ◆.nITGbUipI\n" .
        "Usage: alpha-novel-dl.pl [options]  [目次url] > [保存ファイル]\n".
        "\tアルファポリス投稿小説ダウンローダ\n".
        "\tまとめてダウンロードし標準出力に出力する。\n".
        "\n".
        "\tOption:\n".
        "\t\t-c|--chklist\n".
        "\t\t\t引数に指定したリストを与えると巡回チェックし、\n".
        "\t\t\t新規追加されたデータだけをダウンロードする。\n".
        "\t\t-s|--savedir\n".
        "\t\t\t保存先ディレクトリを指定する。\n".
        "\t\t\t保存先にサブディレクトリを作って個別に保存される。\n".
        "\t\t-u|--update\n".
        "\t\t\tYY.MM.DD形式の日付を与えると、その日付以降の\n".
        "\t\t\tデータだけをダウンロードする。\n".
        "\t\t-n|--dry-run\n".
        "\t\t\t実際には書き込まないで実行する。\n".
        "\t\t-h|--help\n".
        "\t\t\tこのテキストを表示する。\n"
      );
  exit 0;
}

# YYYY.MM.DD -> epoch time.
sub epochtime {
    my $item = shift;
    my ($year, $month, $day) = split(/\./, $item);
    timelocal(0, 0, 0, $day, $month-1, $year-1900);
}

# epochtime -> YYYY.MM.DD
sub timeepoc {
    my $item =shift;
    my ($mday,$month,$year) = (localtime($item))[3,4,5];
    sprintf("%4d.%02d.%02d", $year+1900, $month+1, $mday);
}

# リスト読み込み
sub load_list {
    my $file_name = shift;
    my $LIST;
    my (@item, @list);
    my %hash;
    my $oldsep = $/;
    $/ = "";                    # セパレータを空行に。段落モード
    open ( $LIST, "<:encoding($charcode)" ,"$file_name") or die "$!";
    while (my $line = <$LIST>) {
        push(@item, $line);
    }
    close($LIST);
    $/ = $oldsep;
    # レコード処理
    for (my $i =0; $i <= $#item; $i++) {
        my @record = split('\n', $item[$i]);
        foreach my $field (@record) {
            if ($field =~ /^(title|file_name|url|update)/) {
                my ($key, $value) = split(/=/, $field);
                $key   =~ s/ *//g;
                $value =~ s/^ *//g;
                $value =~ s/"//g;
                if ($value eq "") {
                    print STDERR encode($charcode, "Err:: $field\n");
                    exit 0;
                }
                $hash{$key} = $value; #ハッシュキーと値を追加。
            }
        }
        if ($hash{'title'}) {
            $list[$i] = {%hash}; # ハッシュを配列に格納
        }
        undef %hash;
    }
    undef @item;                #メモリ開放
    return @list;
}

sub save_list {
  my($path, $list) = @_;
  open(STDOUT, ">:encoding($charcode)", $path);
  foreach my $row (@$list) {
    print encode($charcode,
                 "title = " .     $row->{'title'} .     "\n" .
                 "file_name = " . $row->{'file_name'} . "\n" .
                 "url = " .       $row->{'url'} .       "\n" .
                 "update = " .    $row->{'update'} . "\n\n\n"
                 );
  }
  close($path);
}

sub save_novel {
    my $book = shift;
    my $save_file;

    if ( defined( $$book->{'update'} ) ) {
        $last_date = &epochtime( $$book->{'update'} );
        $update = 1;
    }

    $base_path = File::Spec->catfile( $savedir, $$book->{'file_name'} );
    if ($dryrun) {
        if ($^O =~ m/MSWin32/) { $save_file = "nul"; }
        else                   { $save_file = "/dev/null"; }
    }
    else {
        $save_file = &get_path($base_path, $$book->{'file_name'} ) . ".txt";
        }

    open(STDOUT, ">>:encoding($charcode)", $save_file);
    my $body = &get_contents( $$book->{'url'} );
    my $dl_list = &get_index( $body ); # 目次作成
    if (@$dl_list) {
        print STDERR encode($charcode, "START :: " . $$book->{'title'} . "\n");
        unless ($update) {
            print encode($charcode, &header( $body ) );
        }
        &get_all( $dl_list );
        my $num = scalar(@$dl_list) -1;
        # 最後の更新日
        $$book->{'update'} = &timeepoc( $dl_list->[$num]->[2] );
    }
    else {
        print STDERR encode($charcode, "No Update :: " . $$book->{'title'} . "\n");
    }
    close($save_file);
}

# 巡回
sub run_crawl {
    my $check_list = shift;

    foreach my $item (@$check_list){
        &save_novel( \$item );
     }

    unless ($dryrun) {
        &save_list( $chklist, $check_list );
    }

}

sub get_path {
    my ($path, $name) = @_;
    my $fullpath;
    if ( -d $path ) {
        $fullpath = File::Spec->catfile($path, $name);
    }
    else {
        require File::Path;
        File::Path::make_path( $path );
        $fullpath = File::Spec->catfile($path, $name);
        print STDERR encode($charcode, "mkdir :: $fullpath\n");
    }
    return $fullpath;
}

#main
{
    my $url;
    &getopt;

    if ($chklist) {
        unless ($savedir) {
            $savedir = Cwd::getcwd();
        }
        #	print "$chklist\n";
        my @check_list = &load_list( $chklist );
        &run_crawl(\@check_list);
        exit 0;
    }

    if ($update) {
        if ($update =~ m|\d{2}\.\d{2}\.\d{2}| ) {
            $last_date = "20" . $update;
            $last_date = &epochtime( $last_date);
        }
        else {
            print STDERR encode($charcode,
                                "YY.MM.DD の形式で入力してください\n"
                               );
            exit 0;
        }
    }

  if (@ARGV == 1) {
      if ($ARGV[0] =~ m|$url_prefix/novel/\d{8,9}/\d{8,9}/?$|) {
          $url = $ARGV[0];
          my $body = &get_contents( $url );
          my $list = &get_index( $body ); # 目次作成
          print encode($charcode, &header( $body ) );
          &get_all( $list );
      }
      elsif ($ARGV[0] =~ m|$url_prefix.+/episode/|) {
          print STDERR encode($charcode,
                              "個別ページダウンロード未対応\n"
                             );
      }
      else {
          print STDERR encode($charcode,
                              "URLの形式が、『" .
                              "$url_prefix/novel/8〜9桁の数字/8〜9桁の数字" .
                              "』\nと違います" . "\n"
                             );
      }
  }
  else {
      &help;
      exit 0;
  }

  if ($show_help) {
      &help;
      exit 0;
  }
}
