#!/usr/bin/perl
# last updated : 2017/06/15 20:00:11 JST
#
# アルファポリスの投稿小節を青空文庫形式にしてダウンロードする。
# Copyright (c) 2017 ◆.nITGbUipI
# license GPLv2
#
#


use strict;
use warnings;
use LWP::UserAgent;
use HTML::TreeBuilder;
use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use Encode;

my $url = "http://www.alphapolis.co.jp/content/cover/424081493/";
my $user_agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:54.0) Gecko/20100101 Firefox/54.0';
my @url_list = (); # url list
my $separator = "▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼▲▼\n";
my $kaipage = "［＃改ページ］\n";
my $contents;
my ($main_title, $author );

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
  my $mokuji = $item->look_down('class', 'toc cover_body');
  foreach my $tag ($mokuji->find('li')) {
	my $url = $tag->find('a')->attr('href'); # url
	my $title = $tag->look_down('class', 'title')->as_text; # title
	$title = Encode::decode('EUC-JP', $title);
	utf8::decode($title);
	push(@url_list, [$title, $url]); # タイトル,url二組で格納。
  }
}

# 作品名、著者名取得
sub header {
  my $item = shift;
  $item = &html2tree( $item );
  $item = $item->look_down( 'class', 'mainarea');
  $main_title = $item->look_down( 'class', 'title')->as_text;
  $author = $item->look_down( 'class', 'author')->find('a')->as_text;
  $main_title =  Encode::decode('EUC-JP', $main_title);
  $author =  Encode::decode('EUC-JP', $author);
  utf8::decode($main_title);
  utf8::decode($author);
  return sprintf("%s", $main_title . "\n" . $author . "\n\n\n");
}

sub honbun {
  my $item = shift;
  $item =  Encode::decode('EUC-JP', $item);
  utf8::decode($item);
  $item =~ m|.*<div class="text ">(.+)</div>.+<a class="bookmark bookmark_bottom .+|s;
  $item = $1;
  $item =~  s|<br />||g;
  $item =~  s|&nbsp;| |g;
  $item =~  s| +||; # 一行目の空白を削除。
  return $item;
}

sub get_all {
  my $index = shift;
  my $count = @$index;
  for ( my $i = 0; $i < $count; $i++) {
	my $x = &get_contents( scalar(@$index[$i]->[1]) );
	$x = &honbun( $x );
	my $title = scalar(@$index[$i]->[0]);
	print STDERR $title . " ::取得完了\n";
	my $midasi = "\n［＃中見出し］" . $title . "［＃中見出し終わり］\n\n\n";
	my $item = $kaipage . $separator . $midasi . $x . $separator;
	print $item;
	sleep 2;
  }
}


#main
{
  my $body = &get_contents( $url );
  &get_index( $body ); # 目次作成
  print &header( $body );
  &get_all( \@url_list);
}
