#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;
use Digest::MD5 qw(md5_hex);

my $ui = new Bawi::Main::UI(-main_dir=>'admin', -template=>'index.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit(1);
}

$ui->tparam(HTMLTitle => "바위지기 관리기능");

my $id = $auth->id;
$ui->tparam(id=>$id);

$ui->tparam(is_admin=>$auth->is_admin);

print $ui->output;

1;
