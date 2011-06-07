#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;

my $ui = new Bawi::Board::UI(-template=>'online.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $online = $auth->online_bawi;
$ui->tparam(online=>$online);
$ui->tparam(total=>scalar(@$online));

my @l = localtime(time);
my $title = sprintf("접속자 %d월%d일 %d시%d분", $l[4]+1,$l[3],$l[2],$l[1]);
$ui->tparam(HTMLTitle => $title);

print $ui->output;

1;
