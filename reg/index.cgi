#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-main_dir=>'reg');

$ui->init(-template=>'index.tmpl');
my $cfg = $ui->cfg;
my $dbh = $ui->dbh; 

my @term = qw(t1 t2 t3 t4 t5 t6 t7 t8);
my %form = $ui->form(@term);

my $check = 0;

foreach my $i (@term) {
    ++$check unless ($form{$i});
}

if ($check) {
    print $ui->output;
} else {
    print $ui->cgi->redirect("register.cgi");
}
