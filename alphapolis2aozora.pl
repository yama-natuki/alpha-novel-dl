#!/usr/bin/perl
# last updated : 2017/06/21 17:13:27 JST
#
# アルファポリスの投稿小説を青空文庫形式にしてダウンロードする。
# Copyright (c) 2017 ◆.nITGbUipI
# license GPLv2
#
# Usage.
# ./alphapolis2aozora.pl 目次url > 保存先ファイル名
#
# としてリダイレクトすれば青空文庫形式で保存されます。
#
# 特徴
# ・挿絵対応
#     カレントディレクトリに保存されます。
# ・ルビ対応
# ・傍点対応
# ・cp932対応
#     utf8 な環境でしかテストしていません。
#     一応WinではShift_JISで出力するようにはしています。
#
# 変更履歴
# 2017年06月21日(水曜日) 16:55:46 JST
# アルファポリスのサイトリニューアルに伴い、取得できるように書き換えた。
#

use strict;
use warnings;
use LWP::UserAgent;
use HTML::TreeBuilder;
use utf8;
use Encode;
use File::Basename;

my $url;
my $user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0';
my @url_list = (); # url list
my $separator = "▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n";
my $kaipage = "［＃改ページ］\n";
my $contents;
my ($main_title, $author );
my $pic_count = 1;
my $url_prefix = "https://www.alphapolis.co.jp";
my $chapter_title;
my $episode_title;
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
  my $mokuji = $item->look_down('class', 'table-of-contents novels');
  $mokuji = $mokuji->look_down('class', "episodes");
  foreach my $tag ($mokuji->find('div')) {
	my $url = $tag->find('a')->attr('href'); # url
	my $title = $tag->look_down('class', 'title')->as_text; # title
	utf8::decode($title);
	$url = $url_prefix . $url;
	push(@url_list, [$title, $url]); # タイトル,url二組で格納。
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
  $item =~  s/\x0D\x0A/\n/g; #改行コード変換。
  # 章見出し取得
  $item =~  m|<div class="chapter-title">(.+?)</div>|s;
  $chapter_title = $1;
  $chapter_title =~ s/\t//g;
  $chapter_title =~ s/\n//g;
  # 節見出し取得
  $item =~  m|<h2 class="episode-title">(.+?)</h2>|s;
  $episode_title = $1;
  $episode_title =~ s/\t//g;
  $episode_title =~ s/\n//g;
  # 本文取得
  $item =~  m|.*<div class="text ">(.+)</div>.+<a href="/Users/login.+|s;
  $item =   $1;
  $item =~  s|<br />||g;
  $item =~  s|&nbsp;| |g;
  $item =~  s|\t\t||; # 一行目のタブを削除。
  $item =~  s|<ruby>(.+?)<rt>(.+?)</rt></ruby>|｜$1《$2》|g;
  $item =~  s|<em>(.+?)</em>|［＃傍点］$1［＃傍点終わり］|g;
  $item =~  s|</?span>||g;
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
  my $count = @$index;
  my $item;
  for ( my $i = 0; $i < $count; $i++) {
	my $text = &get_contents( scalar(@$index[$i]->[1]) );
	$text = &honbun( $text );
	my $title = scalar(@$index[$i]->[0]);
	print STDERR encode($charcode, $title . " ::取得完了\n");
	my $midasi = "\n［＃中見出し］" . $title . "［＃中見出し終わり］\n\n\n";
	if ( defined($chapter_title) ) {
	  $chapter_title = "\n［＃大見出し］" . $chapter_title . "［＃大見出し終わり］\n";
	  $item = $kaipage . $separator .
	          $chapter_title . $midasi . $text . "\n\n" . $separator;
	}
	else {
	  $item = $kaipage . $separator .
	          $midasi . $text . "\n\n" . $separator;
	}
	print encode($charcode, $item);
	sleep 2;
  }
}


#main
{
  if (@ARGV == 1) {
	if ($ARGV[0] =~ m|$url_prefix/novel/\d{9}/\d{9}/?$|) {
	  $url = $ARGV[0];
	  my $body = &get_contents( $url );
	  &get_index( $body ); # 目次作成
	  print encode($charcode, &header( $body ) );
	  &get_all( \@url_list);
	}
	elsif  ($ARGV[0] =~ m|$url_prefix.+/episode/|) {
	  print encode($charcode, "個別ページダウンロード未対応\n");
	}
  }
  else {
	print encode($charcode,
				 "./alphapolis2aozora.pl  (c) 2017 ◆.nITGbUipI\n" .
				 "アルファポリス投稿小説ダウンローダ\n\n" .
				 "Usage:\n" .
				 "./alphapols2aozora.pl URL\n" .
				 "目次ページを指定してください\n"
				 );
  }
}
