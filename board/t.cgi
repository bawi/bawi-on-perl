#!/usr/bin/perl -w
use warnings;
use strict;

use CGI;

use lib '../lib';
use Bawi::Board::Config;
use Bawi::Board::UI;
use Bawi::Auth;

# %ENV dump (server paths, mod_perl internals): members only -- this
# diagnostic was reachable unauthenticated, same class as main/db-test.cgi
# (PR #34).
my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $q = new CGI;
print $q->header;

foreach my $k (sort keys %ENV) {
  print $k,"\t",$ENV{$k},"<BR>\n";
}
