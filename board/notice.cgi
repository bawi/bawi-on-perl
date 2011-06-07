#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $t = $ui->template;

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $board_id = $ui->cparam('bid') || 0;
my $page = $ui->cparam('p') || 0;
my $article_id = $ui->cparam('aid') || 0;
my $action = $ui->cparam('action') || '';

if ($board_id && $article_id && $action) {
    my $xb = new Bawi::Board(-cfg=>$ui->cfg,
                              -board_id=>$board_id,
                              -dbh=>$ui->dbh);
    if ($xb && $xb->board_id) {
        my $uid = $auth->uid || 0;
        my $is_root = $uid == 1 ? 1 : 0;
        my $is_owner = ($uid == $xb->uid) || $is_root ? 1 : 0;
        if ($is_owner) {
            if ($action eq 'add') {
                $xb->add_notice(-article_id=>$article_id);
            } elsif ($action eq 'del') {
                $xb->del_notice(-article_id=>$article_id);
            }
        }
    }
}

print $ui->cgi->redirect(qq(read.cgi?bid=$board_id&p=$page));
1;
