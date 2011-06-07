#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $atid = $ui->cparam('atid') || undef;
my $bid = $ui->cparam('bid') || undef;

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $attach = $xb->get_attach(-attach_id=>$atid);

my $aid = '';
if ($attach) {
    $aid = $$attach{article_id};
    if ($aid) {
        my $article = $xb->get_article(-article_id=>$aid);
        if ($auth->uid == $$article{uid} && $atid && $bid) {
            $xb->del_attach(-attach_id=>$atid, -board_id=>$bid);
        }
    }
}
print $ui->cgi->redirect("read.cgi?bid=$bid&aid=$aid");

1;
