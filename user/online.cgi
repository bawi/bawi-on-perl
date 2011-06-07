#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'online.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

if ($auth->auth) {
    my $online = $auth->online_bawi;
    $ui->tparam(user=>$online);
    $ui->tparam(total=>scalar(@$online));
    $ui->tparam(menu_online=>1);
    print $ui->output;
} else {
    print $auth->login_page($ui->cgi->url);
}

1;
