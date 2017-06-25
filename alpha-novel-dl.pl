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

my $url_prefix = "https://www.alphapolis.co.jp";
my $user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0';
my $separator = "▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n";
my @url_list = (); # url list
my $kaipage = "［＃改ページ］\n";
my $contents;
my ($main_title, $author );
my $pic_count = 1;
my $chapter_title;
my ($chklist, $savedir, $split_size, $update, $show_help );
my $last_date;  #前回までの取得日
my @check_list; #巡回リスト
my $base_path;  #保存先dir
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
  $item = &html2tree($item);
  my $mokuji = $item->look_down('class', 'table-of-contents novels')
	                ->look_down('class', "episodes");
  foreach my $tag ($mokuji->find('a')) {
	my $url = $tag->find('a')->attr('href'); # url
	my $title = $tag->look_down('class', 'title')->as_text; # title
	utf8::decode($title);
	$url = $url_prefix . $url;
	my $open_date = $tag->look_down('class', 'open-date')->as_text;
	$open_date =~ s|(\d{4}\.\d{2}\.\d{2}) \d.+|$1|;
	$open_date = &epochtime( $open_date );
	if ($update) {
	  if ($open_date > $last_date) {
		push(@url_list, [$title, $url, $open_date]); # タイトル、url、公開日
	  }
	}
	else {
	  push(@url_list, [$title, $url, $open_date]); # タイトル、url、公開日
	}
  }
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
  $item =~  s|\x0D\x0A|\n|g; #改行コード変換。
  # 章見出し取得
  $item =~  m|<div class="chapter-title">(.+?)</div>|s;
  $chapter_title =  $1;
  $chapter_title =~ s|\t||g;
  $chapter_title =~ s|\n||g;
  # 本文取得
  $item =~  m|.*<div class="text ">(.+)</div>.+<a href="/Users/login.+|s;
  $item =   $1;
  $item =~  s|<br />||g;
  $item =~  s|&nbsp;| |g;
  $item =~  s|\t\t||; # 一行目のタブを削除。
  $item =~  s|<ruby>(.+?)<rt>(.+?)</rt></ruby>|｜$1《$2》|g;
  $item =~  s|<em>(.+?)</em>|［＃傍点］$1［＃傍点終わり］|g;
  $item =~  s|</?span>||g;
  $item =~  s|！！|!!|g;
  $item =~  s|！？|!\?|g;
  $item =~ tr|\x{ff5e}|\x{301c}|; #全角チルダ->波ダッシュ
  # 挿絵処理
  if ( $item =~ m|story-image| ) {
	$item =~  s|<a href=.+? class="story-image"><img src="(.+?)" alt=""/></a>|&ins_sasie($1)|e;
	&get_pic( $1);
  }
  return $item;
}

#挿絵リンク処理
sub ins_sasie {
  my $i = shift;
  return "［＃挿絵" .
	     sprintf("%03d", $pic_count) .
		 "（" .
	     File::Basename::basename( $i ) .
		 "）入る］\n";
  $pic_count++;
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
	print STDERR encode($charcode, "success:: $fname\n");
  } else {
	print STDERR encode($charcode, "error:: $fname\n");
  }
}

sub get_all {
  my $index = shift;
  my $count = scalar(@$index);
  my $item;
  for ( my $i = 0; $i < $count; $i++) {
	my $text = &get_contents( scalar(@$index[$i]->[1]) );
	$text = &honbun( $text );
	my $title = scalar(@$index[$i]->[0]);
	my $time = &timeepoc( scalar(@$index[$i]->[2]) );
	$item = &honbun_formater( $text, $title );
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
    "help|h"	  => \$show_help
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
        "\t\t-h|--help\n".
        "\t\t\tこのテキストを表示する。\n"
      );
  exit 0;
}

# YYYY.MM.DD -> epoch time.
sub epochtime {
    my $item = shift;
	my @index = split(/\./, $item);
	my $day   = $index[2];
	my $month = $index[1] -1;
	my $year  = $index[0] -1900;
	return timelocal(00, 00, 00, $day, $month, $year);
}

sub timeepoc {
  my $item =shift;
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime($item);
  $year = 1900 + $year;
  $month++;
  $month = sprintf("%02d", $month);
  $mday = sprintf("%02d", $mday);
  return "$year.$month.$mday";
}

# リスト読み込み
sub load_list {
  my $file_name = shift;
  my $LIST;
  my (@item, @list);
  my %hash;
  my $oldsep = $/;
  $/ = ""; # セパレータを空行に。段落モード
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
	  if ($field =~ /^(title|file|url|update)/) {
		my @atom = split(/=/, $field);
		$atom[0] =~ s/ *//g;
		$atom[1] =~ s/^ *//g;
		$atom[1] =~ s/"//g;
		$hash{$atom[0]} = $atom[1]; #ハッシュキーと値を追加。
	  }
	}
	if ($hash{'title'}) {
	  $list[$i] = {%hash}; # ハッシュを配列に格納
	}
	undef %hash;
  }
  undef @item; #メモリ開放
  return @list;
}

sub save_list {
  my($path, @list) = @_;
  open(STDOUT, ">:encoding($charcode)", $path);
  foreach my $row (@list) {
	print encode($charcode, "title = " . $row->{'title'} . "\n");
	print encode($charcode, "file_name = " . $row->{'file_name'} . "\n");
	print "url = " . $row->{'url'} . "\n";
	print "update = " . $row->{'update'} . "\n\n\n";
  }
  close($path);
}

sub jyunkai_save {
  my $count = scalar(@check_list);
  my $path;
  my $save_file;
  for (my $i = 0; $i < $count; $i++) {
	my $fname = $check_list[$i]->{'file_name'};
	my $url = $check_list[$i]->{'url'};
	my $title = $check_list[$i]->{'title'};
	my $time = $check_list[$i]->{'update'};
	if ( defined($time) ) {
	  $last_date = &epochtime( $time );
	  $update = 1;
	}
	$base_path = File::Spec->catfile( $savedir, $fname );
	$save_file = &get_path($base_path, $fname) . ".txt";
	open(STDOUT, ">>:encoding($charcode)", $save_file);
	my $body = &get_contents( $url );
	&get_index( $body ); # 目次作成
	if (@url_list) {
	  print STDERR encode($charcode, "START :: " . $title . "\n");
	  print encode($charcode, &header( $body ) );
	  &get_all( \@url_list);
	  my $num = scalar(@url_list);
	  $check_list[$i]->{update} = &timeepoc( $url_list[$num -1]->[2] );
	}
	else {
	  print STDERR encode($charcode, "No Update :: " . $title . "\n");
	}
	@url_list = ();
	$base_path = undef;
	$last_date = undef;
	$update = undef;
  }
  close($save_file);
  &save_list( $chklist, @check_list );
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
	@check_list = &load_list( $chklist );
	&jyunkai_save;
	exit 0;
  }
  
  if ($update) {
	if ($update =~ m|\d{2}\.\d{2}\.\d{2}| ) {
	  $last_date = "20" . $update;
	  $last_date = &epochtime( $last_date);
	}
  }

  if (@ARGV == 1) {
	if ($ARGV[0] =~ m|$url_prefix/novel/\d{8,9}/\d{8,9}/?$|) {
	  $url = $ARGV[0];
	  my $body = &get_contents( $url );
	  &get_index( $body ); # 目次作成
	  print encode($charcode, &header( $body ) );
	  &get_all( \@url_list);
	}
	elsif  ($ARGV[0] =~ m|$url_prefix.+/episode/|) {
	  print STDERR encode($charcode,
                          "個別ページダウンロード未対応\n");
	}
	else {
	  print STDERR encode($charcode,
                          "URLの形式が、『" .
                          "$url_prefix/novel/8〜9桁の数字/8〜9桁の数字" .
                          "』\nと違います" . "\n");
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
