#!/usr/bin/perl -w
use strict;
use lib '../lib';

use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI( -template=>'career.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);
$ui->tparam(menu_profile=>1);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $uid = $auth->uid || 0;
$ui->tparam(id=>$auth->id);
$ui->tparam(name=>$auth->name);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

my @field = qw(
action
cid
type
org
org_id
position
start_year
start_month
end_year
end_month
);

my ($action, $career_id, $type, $org, $param_org_id, $position, $s_year, $s_month, $e_year, $e_month) = map { $ui->cparam($_) || '' } @field;
my %type = map { $_=>1 } qw(employment internship volunteer research military other);
my @msg;

$career_id = '' unless ($career_id && $career_id =~ /^\d+$/);
$type = 'employment' unless ($type && $type{$type});
$org =~ s/^\s+//;
$org =~ s/\s+$//;
$position =~ s/^\s+//;
$position =~ s/\s+$//;
if (length($org) > 128) {
    $org = substr($org, 0, 128);
    push @msg, '회사/기관명은 128자까지만 저장됩니다.';
}
if (length($position) > 255) {
    $position = substr($position, 0, 255);
    push @msg, '직위/직책은 255자까지만 저장됩니다.';
}

$s_year = '' unless ($s_year =~ /^(1001|\d\d\d\d)$/);
$e_year = '' unless ($e_year =~ /^(1001|\d\d\d\d)$/);
$s_month = '' unless ($s_month =~ /^(00|0[1-9]|1[0-2])$/);
$e_month = '' unless ($e_month =~ /^(00|0[1-9]|1[0-2])$/);

my $s_date;
if ($s_year && $s_year ne '1001') {
    $s_month = '01' if ($s_month eq '' || $s_month eq '00');
    $s_date = "$s_year-$s_month-01";
}

my $e_date;
if ($e_year && $e_year ne '1001') {
    $e_month = '12' if ($e_month eq '' || $e_month eq '00');
    $e_date = "$e_year-$e_month-01";
}

if ($s_date && $e_date && $e_date lt $s_date) {
    $e_date = undef;
    push @msg, '종료일이 시작일보다 앞서 있어 종료일을 현재로 저장했습니다.';
}

if ($uid && $action && $action eq 'save') {
    my @missing;
    push @missing, '회사/기관명' unless length($org);
    push @missing, '직위/직책' unless length($position);
    if (@missing) {
        push @msg, '입력해주세요: ' . join(', ', @missing);
    } else {
        $org = $ui->cgi->escapeHTML($org);
        $position = $ui->cgi->escapeHTML($position);
        my $org_id = $user->resolve_or_create_org($org, $uid);
        if ($org_id) {
            my $rv = $career_id ?
                $user->update_career($career_id, $uid, $type, $org_id, $position, $s_date, $e_date) :
                $user->add_career($uid, $type, $org_id, $position, $s_date, $e_date);
            if ($rv && $rv ne '0E0') {
                $user->modified($uid);
            } else {
                push @msg, '저장하지 못했습니다. 다시 시도해주세요.';
            }
        } else {
            push @msg, '저장하지 못했습니다. 다시 시도해주세요.';
        }
    }
}

if ($uid && $career_id && $action && $action eq 'del') {
    my $rv = $user->del_career($uid, $career_id);
    $user->modified($uid) if ($rv && $rv eq '1');
}

$ui->msg(join("<br>", @msg)) if @msg;

if ($uid) {
    $ui->tparam(ki=>$user->ki($uid));
    $ui->tparam(careers=>$user->get_career($uid));
    $ui->tparam(career_set=>$user->career_set($uid));
}
print $ui->output;

1;
