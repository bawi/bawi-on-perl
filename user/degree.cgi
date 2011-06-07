#!/usr/bin/perl -w
use strict;
use lib '../lib';

use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI( -template=>'degree.tmpl');
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
did
type
school_id
department
advisors
content
start_year
start_month
end_year
end_month
status
);

my ($action, $degree_id, $type, $school_id, $department, $advisors, $content, $s_year, $s_month, $e_year, $e_month, $status) = map { $ui->cparam($_) || '' } @field;

if ($e_year && $s_year && 
    ( ($e_year ne '0000' && $e_year < $s_year) || 
      $s_year eq '0000' || 
      ($e_year eq $s_year && $e_month < $s_month) ) ) {
    $e_year = '';
    $e_month = '';
}

$s_month = '' if ($s_month eq '00' || $s_year eq '0000');
$s_year = '' if ($s_year eq '0000');

my $s_date = "$s_year-$s_month-01"
    if ($s_year && $s_month);
my $e_date = "$e_year-$e_month-01"
    if ($e_year && $e_month);

if ($uid && $type && $school_id && $department && $s_date && $e_date) {
    my @field = ($uid, $type, $school_id, $department, $advisors, $content, $s_date, $e_date, $status);
    $field[3] = $ui->cgi->escapeHTML($field[3]);
    $field[4] = $ui->cgi->escapeHTML($field[4]);
    $field[5] = $ui->cgi->escapeHTML($field[5]);
    if ($field[4] =~ /교수|선생|prof|dr/i) {
        $field[4] =~ s/\s*(교수님|선생님|교수|선생)\s*//gi;
        $field[4] =~ s/\s*(dr|prof|professor)\.?\s+//gi;
    }
    if ($degree_id) {   # update existing record
        my $rv = $user->update_degree($degree_id, @field);
        $user->modified($uid);
    } else {            # insert new record
        my $rv = $user->add_degree(@field);
        $user->modified($uid);
    }
}

if ($uid && $degree_id && $action && $action eq 'del') {
    my $rv = $user->del_degree($uid, $degree_id);
    $user->modified($uid) if ($rv && $rv eq '1');
}

if ($uid) {
    $ui->tparam(ki=>$user->ki($uid));
    $ui->tparam(degrees=>$user->get_degree($uid));
    $ui->tparam(degree_set=>$user->degree_set($uid));
}
print $ui->output;

1;
