#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::User;
use Bawi::User::UI;
use Bawi::Auth;

my $ui = new Bawi::User::UI(-template=>'major.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);
my $dbh = $ui->dbh; 

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $uid = $auth->uid;
my $category = $ui->cparam('category') || '';
my $major_id = $ui->cparam('major_id') || '';
my $del_id = $ui->cparam('del_id') || '';

if ($major_id) {
    my $sql = qq(insert ignore into bw_user_major (uid, major_id) values (?,?));
    my $rv = $dbh->do($sql, undef, $uid, $major_id);
    $user->modified($uid) if ($rv && $rv eq '1');
}

if ($del_id) {
    my $sql = qq(delete from bw_user_major where uid=? && major_id=?);
    my $rv = $dbh->do($sql, undef, $uid, $del_id);
    $user->modified($uid) if ($rv && $rv eq '1');
}

my $sql = qq(select a.major, a.major_id from bw_data_major as a, bw_user_major as b where a.major_id=b.major_id && b.uid=?);
my $major = $dbh->selectall_arrayref($sql, undef, $uid);
my %major;
if ($major) {
    my @major = map {$major{$$_[1]} = 1; { major=>$$_[0], major_id=>$$_[1] }} @$major;
    $ui->tparam(major=>\@major);
}

$sql = qq(select major_id, major from bw_data_major where parent_id=0);
my $cat = $dbh->selectall_hashref($sql, 'major_id');
my @category = map { $$cat{$_}->{current} = $$cat{$_}->{major_id} eq $category ? 1 : 0; $$cat{$_} }
                sort { $$cat{$a}->{major_id} <=> $$cat{$b}->{major_id} }
                    keys %$cat;
$ui->tparam(category=>\@category);

if ($category) {
    my $sql = qq(select major_id, major from bw_data_major where parent_id=?);
    my $maj = $dbh->selectall_hashref($sql, 'major_id', undef, $category);
    my @major_list = map { $$maj{$_}->{current} = exists $major{ $$maj{$_}->{major_id} } ? 1 : 0; $$maj{$_} }
                        sort { $$maj{$a}->{major} cmp $$maj{$b}->{major} }
                            keys %$maj;
    $ui->tparam(major_list=>\@major_list);
}

$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);
print $ui->output;
