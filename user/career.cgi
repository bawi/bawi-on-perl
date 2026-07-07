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

my ($action, $career_id, $company, $position, $s_year, $s_month, $e_year, $e_month) = map { $ui->cparam($_) || '' } @field;

if ($e_year && $s_year && 
    ( ($e_year ne '1001' && $e_year < $s_year) || 
      $s_year eq '1001' || 
      ($e_year eq $s_year && $e_month < $s_month) ) ) {
    $e_year = '';
    $e_month = '';
}

$s_month = '' if ($s_month eq '00' || $s_year eq '1001');
$s_year = '' if ($s_year eq '1001');

$e_month = '01' if ($e_year eq '1001');

my $s_date = ($s_year && $s_month) ? "$s_year-$s_month-01" : '1001-01-01';
my $e_date = ($e_year && $e_month) ? "$e_year-$e_month-01" : '1001-01-01';

if ($uid && $company && $position) {
    my @field = ($uid, $company, $position, $s_date, $e_date);
    $field[1] = $ui->cgi->escapeHTML($field[1]);
    $field[2] = $ui->cgi->escapeHTML($field[2]);
    if ($career_id) {   # update existing record
        my $rv = $user->update_career($career_id, @field);
        $user->modified($uid);
    } else {            # insert new record
        my $rv = $user->add_career(@field);
        $user->modified($uid);
    }
}

if ($uid && $career_id && $action && $action eq 'del') {
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
