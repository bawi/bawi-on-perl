#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'majors.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);
my $dbh = $ui->dbh; 

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $uid= $auth->uid || 0;
$ui->tparam(menu_major=>1);

my $mid = $ui->cparam('mid') || '';
my $pid = $ui->cparam('pid') || '';
my $c = $ui->cparam('c') ||  '';

$ui->tparam(category=>&category_list($pid));
$ui->tparam(majors=>&major_list($mid, $pid)) if ($pid);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

if ($mid) {
    if ($c && $c eq 'add') {
        &add_user($mid, $uid);
    } elsif ($c && $c eq 'del') {
        &del_user($mid, $uid);
    }
    my $user = &user($mid);
    $ui->tparam(user=>$user);
    $ui->tparam(major_id=>$mid);
    $ui->tparam(parent_id=>$pid);
    $ui->tparam(total=>scalar(@$user));
    $ui->tparam(is_member=>&is_major_member($mid, $uid));
}
$ui->tparam(has_major=>$user->has_major($auth->uid));

print $ui->output;

sub user {
    my ($mid) = @_;
    my $sql = qq(select a.ki, b.id, b.name
                 from bw_user_ki as a, bw_xauth_passwd as b, bw_user_major as c 
                 where a.uid=b.uid && b.uid=c.uid && c.major_id=?
                 order by a.ki, b.name);
    my $rv = $dbh->selectall_hashref($sql, 'id', undef, $mid);
    my @rv = map { $$rv{$_} }
                sort { $$rv{$a}->{ki} <=> $$rv{$b}->{ki} ||
                       $$rv{$a}->{name} cmp $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub add_user {
    my ($mid, $uid) = @_;
    my $sql = qq(replace into bw_user_major (major_id, uid) values (?,?));
    my $rv = $dbh->do($sql, undef, $mid, $uid);
    return $rv;
}

sub del_user {
    my ($mid, $uid) = @_;
    my $sql = qq(delete from bw_user_major where major_id=? && uid=?);
    my $rv = $dbh->do($sql, undef, $mid, $uid);
    return $rv;
}

sub category_list {
    my $pid = shift;
    my $sql = qq(select a.major, a.major_id, count(*) as count 
                 from bw_data_major as a, bw_user_major as b, bw_data_major as c
                 where b.major_id=c.major_id && a.major_id=c.parent_id && 
                       a.parent_id=0 
                 group by a.major_id 
                 order by a.major);
    my $rv = $dbh->selectall_hashref($sql, 'major_id');
    my @rv = map { $$rv{$_}->{current} = $pid eq $_ ? 1 : 0; $$rv{$_} }
                sort { $$rv{$a}->{major} cmp $$rv{$b}->{major} }
                    keys %$rv;
    return \@rv;
}

sub major_list {
    my ($mid, $pid) = @_;
    my $sql = qq(select a.major, a.major_id, count(b.major_id) as count
                 from bw_data_major as a left join bw_user_major as b
                 on a.major_id=b.major_id
                 where a.parent_id=?
                 group by a.major_id
                 order by a.major);
    my $rv = $dbh->selectall_hashref($sql, 'major_id', undef, $pid);
    my @rv = map { $$rv{$_}->{current} = $mid eq $_ ? 1 : 0; $$rv{$_} }
                sort { $$rv{$a}->{major} cmp $$rv{$b}->{major} }
                    keys %$rv;
    return \@rv;
}

sub is_major_member {
    my ($mid, $uid) = @_;
    my $sql = qq(select uid from bw_user_major where major_id=? && uid=?);
    my $rv = $dbh->selectrow_array($sql, undef, $mid, $uid);
    if ($rv && $rv == $uid) {
        return 1;
    } else {
        return 0;
    }
}

1;
