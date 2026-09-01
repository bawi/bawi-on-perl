#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use HTML::ParseBrowser;
use GeoIP2::WebService::Client;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $DBH = $ui->dbh;
unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

################################################################################
## main
################################################################################
my ($uid, $id, $name, $session_key);
if ($auth->auth) {
    ($uid, $id, $name, $session_key) = ($auth->uid, $auth->id, $auth->name, $auth->session_key);
} else {
    ($uid, $id, $name, $session_key) = (0, 'guest', 'guest', '');
}

# SECURITY: hardcoded GeoIP2 credentials removed (were exposed in a public push; rotate the key and load from config before enabling this feature).
my $geoip_account_id  = '';   # TODO: load from conf/*.conf
my $geoip_license_key = '';   # TODO: load from conf/*.conf
my $client = GeoIP2::WebService::Client->new(account_id=>$geoip_account_id, license_key=>$geoip_license_key);
my $insights = $client->insights(ip => $ENV{'REMOTE_ADDR'});
my $ip = $insights->city()->name().", ".$insights->country()->name();
$ui->init(-template=>'mysessions.tmpl');
my $t = $ui->template;
$t->param(HTMLTitle=>"나의 접속 기기 보기 ".$name."(".$id.")");
$t->param(name=>$name);
$t->param(id=>$id);
$t->param(url=>"mysessions");
$t->param(ua=>$ip);
my $sql = qq(SELECT session_key, uid, id, name, created, ip_address, user_agent FROM bw_xauth_session WHERE uid=?);
my $rv = $DBH->selectall_hashref($sql, "uid", undef, $uid);
my @rv = map { $rv->{$_} } sort {$b <=> $a} keys %$rv;
$t->param(sessions=>\@rv);

# navigation
print $ui->output;

1;
