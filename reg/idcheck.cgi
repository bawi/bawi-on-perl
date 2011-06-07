#!/usr/bin/perl -w
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-main_dir=>'reg');

$ui->init(-template=>'idcheck.tmpl');

my $cfg = $ui->cfg;
my $dbh = $ui->dbh; 
my $auth = new Bawi::Auth(-cfg=>$cfg, -dbh=>$dbh);

my $id = $ui->cparam('id') || '';

if ($id) {
    $ui->tparam(id=>$id);
    if ($id =~ /^[a-z]([0-9a-z])+$/ && length($id) > 2 && length($id) < 9 && 
        $auth->exists_id(-id=>$id) == 0 && $auth->exists_new_id(-id=>$id) == 0) {
        $ui->tparam(exists_id=>0);
    } else {
        $ui->tparam(exists_id=>1);
    }
}


print $ui->output;
