#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI( -template=>'guestbook.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

$ui->tparam(menu_profile=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

my $guest_uid = $auth->uid;
my ($uid, $body, $reply, $gbook_id, $page, $action, $left) 
    = map { $ui->cparam($_) || ''} qw(uid body reply gbook_id page action left);

$page = 1 unless ($page);
$left = 0 unless ($left);
$ui->tparam(left=>$left);
$uid = $auth->uid unless ($uid);
my $owner = $auth->get_user(-uid=>$uid);
$ui->tparam(uid=>$uid);
$ui->tparam(ki=>$user->ki($uid));
$ui->tparam(name=>$owner->{name});
$ui->tparam(id=>$owner->{id});
$ui->tparam(birth=>$owner->{birth});
$ui->tparam(death=>$owner->{death});
my $is_owner = $uid == $guest_uid ? 1 : 0;
$ui->tparam(is_owner=>$is_owner);

if ($uid && $body && $uid != $guest_uid) {
    $body = $ui->cgi->escapeHTML($body);
    my $rv = $user->add_guestbook($uid, $guest_uid, $body);
}

if ($gbook_id && $reply && $uid == $guest_uid) {
    $reply = $ui->cgi->escapeHTML($reply);
    my $rv = $user->add_guestbook_reply($gbook_id, $reply);
}

if ($gbook_id && $action && $action eq 'del') {
    my $rv = $user->del_guestbook($gbook_id, $guest_uid);
}

if ($gbook_id && $action && $action eq 'delrep') {
    my $rv = $user->del_guestbook_reply($gbook_id, $guest_uid);
}

if ($is_owner && $action eq 'stat') {
    my ($stat, $tot_s, $tot_r, $tot_arrow) = $user->get_guestbook_stat($uid);
    $ui->tparam(stat=>$stat);
    $ui->tparam(stat_tot=>scalar(@$stat));
    $ui->tparam(tot_r=>$tot_r);
    $ui->tparam(tot_s=>$tot_s);
    $ui->tparam(tot_arrow=>$tot_arrow);
} elsif ($uid == $guest_uid && $left == 1) {
    $ui->tparam(guestbook => $user->get_left_guestbookset($uid, $guest_uid, $page));
    $ui->tparam(%{ $user->get_guestbook_pagenav($uid, $page, 1) });
} else {
    $ui->tparam(guestbook => $user->get_guestbookset($uid, $guest_uid, $page));
    $ui->tparam(%{ $user->get_guestbook_pagenav($uid, $page, 0) });
}


print $ui->output;

1;
