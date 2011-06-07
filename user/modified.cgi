#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'modified.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->tparam(menu_modified=>1);
my $list = $user->modified_user;
$ui->tparam(list=>$list);
$ui->tparam(total=>scalar(@$list));
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

print $ui->output;

1;
