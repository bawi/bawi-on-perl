#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;
use Digest::MD5 qw(md5_hex);

my $ui = new Bawi::Main::UI(-template=>'denied.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
$auth->auth;
=rem
unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit(1);
}
=cut

$ui->tparam(HTMLTitle => "안내 - 접근할 수 없습니다");

my $msg = qq(You don't have permission to access on this page.);
my $url = $ui->cparam('url');
$msg .= qq(<br/>Page: <a href="$url">$url</a>.) if $url;
    
$ui->msg($msg);

my $id = $auth->id;
$ui->tparam(id=>$id);

$ui->tparam(is_admin=>$auth->is_admin);

print $ui->output;

1;
