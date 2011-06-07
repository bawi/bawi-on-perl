#!/usr/bin/perl -w
use strict;

use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'circle.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}
my $uid = $auth->uid;
my $cid = $ui->cparam('cid') || '';
my $msg = $ui->cparam('msg') || '';
my $ki = $ui->cparam('ki') || '';

$ui->tparam(circle_list=>$user->circle_list($cid));
$ui->tparam(menu_circle=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

if ($cid) {
    $ui->tparam(cid=>$cid);
    my $c = $ui->cparam('c') || '';
    if ($c && $c eq 'add') {
        my $rv = $user->add_circle_member($cid, $uid);
        #$user->modified($uid) if ($rv && $rv eq '1');
    } elsif ($c && $c eq 'del') {
        my $rv = $user->del_circle_member($cid, $uid);
        #$user->modified($uid) if ($rv && $rv eq '1');
    }
    my $users = $user->circle_member($cid);
    $ui->tparam(user=>$users);
    $ui->tparam(total=>scalar(@$users));
    $ui->tparam(circle_id=>$cid);
    my $is_member = $user->is_circle_member($cid, $uid);
    $ui->tparam(is_member=>$is_member);
    my %ki;
    my @t = map { $ki{ $$_{ki} } = 1; $$_{ki} } @$users;
    my @note_ki = map { { ki=>$_ } } sort { $a <=> $b } keys %ki;
    $ui->tparam(note_ki=>\@note_ki);
    if ($msg && $is_member) {
        my @id;
        if ($ki) {
            @id = map { $$_{id} } grep { $$_{ki} == $ki } @$users;
        } else {
            @id = map { $$_{id} } @$users;
        }
        my $rv = $user->note($auth->id, $auth->name, $msg, \@id);
    }
}
$ui->tparam(has_circle=>$user->has_circle($uid));

print $ui->output;

1;
