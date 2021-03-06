#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $q = $ui->cgi;
my $session_key = $q->param('s') || '';

unless ($auth->auth(-session_key=>$session_key)) {
	print $auth->login_page($ui->cgiurl);
	exit (1);
}

my ($uid, $id, $name) = ($auth->uid, $auth->id, $auth->name);
my ($bid, $aid, $p) = map { $q->param($_) || undef } qw( bid aid p );

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);

if ($aid && $uid) {
    my $article_uid = $xb->get_article_uid(-article_id=>$aid);
    my $rv = $xb->get_scrap(-article_id=>$aid, -uid=>$uid);
    if ($rv) {
        my $rv2 = $xb->delete_scrap(-article_id=>$aid, -uid=>$uid);
	}
}

if ($session_key) {
	print $q->redirect("read_scrap.cgi?bid=$bid&p=$p");
} else  {
	print $q->redirect("read_scrap.cgi?bid=$bid&p=$p");
}
1;
