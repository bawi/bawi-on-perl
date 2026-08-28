#!/usr/bin/perl -w
use strict;
use warnings;
use lib '../lib';
use Bawi::Main::UI;

#$ENV{BAWI_PERL_HOME} = "/home/bawi/bawi-perl/";
#$ENV{BAWI_DATA_HOME} = "/home/bawi/bawi-data/";

my $ui = new Bawi::Main::UI(-template=>'index.tmpl');

# Diagnostic page: enumerates every board title. Members only -- this was
# reachable unauthenticated on prod, handing anonymous visitors a complete
# board directory (closed boards included). PR #34.
use Bawi::Auth;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

print $ui->cgi->header(-type=>'text/plain');
my $dbh = $ui->dbh;
print "before query: ",$dbh->state,"\n";
my $sth = $dbh->prepare("select title, name from bw_xboard_board where board_id < ?");
print "after query: ",$dbh->state,"\n";
print "dbh->errstr: ",$dbh->errstr,"\n";
$sth->execute(100);

while( my @tmp = $sth->fetchrow_array() ) {
    print $tmp[0],"\n";
}
$dbh->disconnect();
