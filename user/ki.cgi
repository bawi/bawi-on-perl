#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::User;
use Bawi::Auth;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'ki.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $ki = $ui->cparam('ki') || '';
my $msg = $ui->cparam('msg') || '';

$ui->tparam(ki_list=>$user->ki_list($ki));
$ui->tparam(menu_ki=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

if ($ki) {
    $ui->tparam(ki=>$ki);
    my $users = $user->user_ki($ki);
    $ui->tparam(user=>$users);
    $ui->tparam(total=>scalar(@$users));
    my $is_ki = $ki eq $user->ki($auth->uid) ? 1 : 0;
    $ui->tparam(is_ki=>$is_ki);
    $ui->tparam(is_member=>$is_ki);
    $ui->tparam(has_msn => $user->has_im($auth->uid, 'msn') );
    if ($msg && $is_ki) {
        my @id = map { $$_{id} } @$users;
        my $rv = $user->note($auth->id, $auth->name, $msg, \@id);
    }
    
}

print $ui->output;

