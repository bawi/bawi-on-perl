#!/usr/bin/perl -w
# XXX NOT USED - aragorn, 2010-04-19
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board::UI;
use Bawi::Board;

my $ui = new Bawi::Board::UI(-template=>'apply.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $xb = new Bawi::Board(-cfg=>$ui->cfgi, -dbh=>$ui->dbh);

print $ui->output;
1;
