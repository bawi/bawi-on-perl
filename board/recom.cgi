#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $q = $ui->cgi;

my ($uid, $id, $name) = ($auth->uid, $auth->id, $auth->name);

my ($bid, $aid, $p) = map { $q->param($_) || undef } qw( bid aid p );

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);

if ($aid && $uid) {
  my $article_uid = $xb->get_article_uid(-article_id=>$aid);
  my $rv = $xb->get_recommender(-article_id=>$aid, -uid=>$uid);
  if (!$rv && $article_uid ne $uid && $xb->allow_recom) {
    my $rv1 = $xb->add_recommender(-article_id=>$aid, -uid=>$uid);
    my $rv2 = $xb->add_comment(-board_id   => $bid,
                               -article_id => $aid,
                               -body       => '추천합니다!',
                               -uid        => $uid,
                               -id         => $id,
                               -name       => $name)
        if ($rv1 && $ui->cfg->AllowRecomComment);
  }
}
print $q->redirect("read.cgi?bid=$bid&p=$p");
1;
