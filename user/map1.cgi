#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'map.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $uid = $auth->uid;

my $mapset = $user->get_mapset();
$ui->tparam(mapset=>$mapset);
$ui->tparam(menu_map=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);


print $ui->output;
1;
