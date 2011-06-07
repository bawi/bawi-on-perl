#!/usr/bin/perl -w
use strict;
use lib "../lib";
use CGI;
use Bawi::Auth;
use Bawi::User::UI;

my $UPDIR = "/home/bawi/photo_attach/";

my $q = new CGI;
my $ui = new Bawi::User::UI(-template=>"uphoto.tmpl");
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
  print $auth->login_page;
  exit(1);
}

my $uid = $q->param("uid");
if ($uid !~ /[0-9]*/) {
  $ui->tparam(bad_access=>1);
  print $ui->output;
} else {
  my $out = $UPDIR . $uid . ".jpg";
  print $ui->cgi->header(-type=>'image/jpeg', -expires=>'-1d');
  open(FH, "< $out") or die("Can't open file $out: $!\n");
  while (<FH>) {
  	print;
  }
  close FH;
}
1;

