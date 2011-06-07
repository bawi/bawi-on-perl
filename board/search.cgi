#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;

my $ui = new Bawi::Board::UI(-template=>'search.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

$ui->tparam(HTMLTitle => "찾기");

my ($keyword, $field) = map { $ui->cparam($_) || '' } qw(keyword field);
$ui->tparam(keyword=>$keyword);
$ui->tparam(field=>$field);

$field = 'title' unless $field; 
my @search_fields;
my @field = qw(title body name id);
foreach my $i (@field) {
    my $checked = $i eq $field ? 1 : 0;
    push @search_fields, { field=>$i, checked=>$checked };
}
$ui->tparam(search_fields=>\@search_fields);

print $ui->output;
1;
