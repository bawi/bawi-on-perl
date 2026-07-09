#!/usr/bin/perl -w
use strict;
use lib '../lib';

use Encode ();
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
my %type = map { $_=>1 } keys %Bawi::User::CAREER_TYPE;
my @msg;

$career_id = '' unless ($career_id && $career_id =~ /^\d+$/);
$type = 'employment' unless ($type && $type{$type});
$org = Encode::decode_utf8($org, Encode::FB_DEFAULT);
$position = Encode::decode_utf8($position, Encode::FB_DEFAULT);
$org =~ s/^\s+|\s+$//g;  $position =~ s/^\s+|\s+$//g;

# 1001 (year) / 00 (month) = the '현재' sentinel emitted by year_list/month_list; it
# means "no date" and maps to SQL NULL below (never a 1001-01-01 row).
my $this_year = (localtime)[5] + 1900;
$s_year = '' unless ($s_year eq '1001' || ($s_year =~ /\A\d{4}\z/ && $s_year >= 1991 && $s_year <= $this_year));
$e_year = '' unless ($e_year eq '1001' || ($e_year =~ /\A\d{4}\z/ && $e_year >= 1991 && $e_year <= $this_year));
$s_month = '' unless ($s_month =~ /\A(00|0[1-9]|1[0-2])\z/);
$e_month = '' unless ($e_month =~ /\A(00|0[1-9]|1[0-2])\z/);

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
        my $org_esc = $ui->cgi->escapeHTML($org);
        my $position_esc = $ui->cgi->escapeHTML($position);
        if (length($org_esc) > 128) {
            push @msg, '회사/기관명이 너무 깁니다.';
        } elsif (length($position_esc) > 255) {
            push @msg, '직위/직책이 너무 깁니다.';
        } else {
            $org = Encode::encode_utf8($org_esc);
            $position = Encode::encode_utf8($position_esc);
            # trust the type-ahead's picked org_id when it names a real org (JS clears it on
            # edit, so its presence means an unmodified pick); else resolve/create by name.
            my $org_id = ($param_org_id =~ /^\d+$/ && $param_org_id > 0 && $user->org_exists($param_org_id))
                         ? $param_org_id
                         : $user->resolve_or_create_org($org, $uid);
            if ($org_id) {
                my $rv = $career_id ?
                    $user->update_career($career_id, $uid, $type, $org_id, $position, $s_date, $e_date) :
                    $user->add_career($uid, $type, $org_id, $position, $s_date, $e_date);
                if ($rv) {
                    $user->modified($uid);
                } else {
                    push @msg, '저장하지 못했습니다. 다시 시도해주세요.';
                }
            } else {
                push @msg, '저장하지 못했습니다. 다시 시도해주세요.';
            }
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
