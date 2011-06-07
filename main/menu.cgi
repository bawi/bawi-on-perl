#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI( -template=>'menu.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $id = $auth->id;
$ui->tparam(id=>$id);
$ui->tparam(is_admin=>Bawi::Auth::is_admin($id));

my $dev = "";
$dev = $ENV{SERVER_NAME} if (exists $ENV{SERVER_NAME} and ($ENV{SERVER_NAME} ne "www.bawi.org"));
$ui->tparam(dev=>$dev);

print $ui->output;
1;
