#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'class.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $uid = $auth->uid;
my ($ki, $grade, $class, $msg) = map { $ui->cparam($_) || ''} qw(ki grade class msg);

$ui->tparam(menu_class=>1);
$ui->tparam(ki_list=>$user->ki_list($ki));
$ui->tparam(has_class=>$user->has_class($uid));
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

if ($ki && $grade && $class) {
    my $is_ki = $ki eq $user->ki($uid) ? 1 : 0;
    $ui->tparam("g$grade"=>1);
    $ui->tparam("c$class"=>1);
    my $users = $user->get_class($ki, $grade, $class);
    $ui->tparam(user=>$users);
    $ui->tparam(total=>scalar(@$users));
    $ui->tparam(is_ki=>$is_ki);
    $ui->tparam(ki=>$ki);
    $ui->tparam(grade=>$grade);
    $ui->tparam(class=>$class);
    my $is_member = $user->is_class($uid, $ki, $grade, $class);
    $ui->tparam(is_member=>$is_member);
    if ($msg && $is_member) {
        my @id = map { $$_{id} } @$users;
        my $rv = $user->note($auth->id, $auth->name, $msg, \@id);
    }
}

print $ui->output;
1;
