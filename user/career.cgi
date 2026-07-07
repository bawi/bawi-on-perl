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
company
position
start_year
start_month
end_year
end_month
);

# // (not ||) so a literal "0" in company/position survives the default.
my ($action, $career_id, $company, $position, $s_year, $s_month, $e_year, $e_month) = map { $ui->cparam($_) // '' } @field;

for ($company, $position) { s/^\s+//; s/\s+$//; }

# Dates are optional. Normalize the "현재" sentinels (year 1001 / month 00):
# a real year whose month is left at 현재 defaults to January (keep the year,
# never silently drop it); a year left at 현재 means "no date" and clears its
# month so the date collapses to the 1001-01-01 sentinel.
$s_year = '' if ($s_year eq '1001');
$e_year = '' if ($e_year eq '1001');
$s_month = '01' if ($s_year && (!$s_month || $s_month eq '00'));
$e_month = '01' if ($e_year && (!$e_month || $e_month eq '00'));
$s_month = '' unless $s_year;
$e_month = '' unless $e_year;

# Only a real end preceding a real start is invalid; an unknown (blank) start
# must never invalidate a known end.
if ($s_year && $e_year &&
    ($e_year < $s_year || ($e_year == $s_year && $e_month < $s_month))) {
    $e_year = '';
    $e_month = '';
}

my $s_date = ($s_year && $s_month) ? "$s_year-$s_month-01" : '1001-01-01';
my $e_date = ($e_year && $e_month) ? "$e_year-$e_month-01" : '1001-01-01';

if ($action eq 'save' && $uid && length($company) && length($position)) {
    my @field = ($uid, $company, $position, $s_date, $e_date);
    $field[1] = $ui->cgi->escapeHTML($field[1]);
    $field[2] = $ui->cgi->escapeHTML($field[2]);
    my $rv = $career_id ? $user->update_career($career_id, @field)
                        : $user->add_career(@field);
    if ($rv) {
        $user->modified($uid);
    } else {
        $ui->msg('저장에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    }
}

if ($action eq 'save' && !(length($company) && length($position))) {
    my @missing;
    push @missing, '회사명' unless length $company;
    push @missing, '직위/직책' unless length $position;
    $ui->msg(join(', ', @missing) . ' 항목을 입력해야 저장됩니다.');
}

if ($uid && $career_id && $action eq 'del') {
    my $rv = $user->del_career($uid, $career_id);
    $user->modified($uid) if ($rv && $rv eq '1');
}

if ($uid) {
    $ui->tparam(ki=>$user->ki($uid));
    $ui->tparam(careers=>$user->get_career($uid));
    $ui->tparam(career_set=>$user->career_set($uid));
}
print $ui->output;

1;
