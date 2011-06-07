#!/usr/bin/perl -w
use strict;
use warnings;
use lib '../lib';
use Bawi::Main::UI;

#$ENV{BAWI_PERL_HOME} = "/home/bawi/bawi-perl/";
#$ENV{BAWI_DATA_HOME} = "/home/bawi/bawi-data/";

my $ui = new Bawi::Main::UI(-template=>'index.tmpl');

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
