#!/usr/bin/perl -w
use strict;
use warnings;
use lib '../lib';
use Bawi::Main::UI;
use Bawi::Auth;

#$ENV{BAWI_PERL_HOME} = "/home/bawi/bawi-perl/";
#$ENV{BAWI_DATA_HOME} = "/home/bawi/bawi-data/";

my $ui = new Bawi::Main::UI(-template=>'index.tmpl');

# DB diagnostic page, members only (PR #34): it was reachable
# unauthenticated on prod. It also used to print every board title
# (board_id < 100), which after 3839308's front-page fix would hand any
# member the closed-board directory -- so it now reports only a row count.
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

my $n = 0;
$n++ while $sth->fetchrow_array();
print "boards: $n\n";
$dbh->disconnect();
