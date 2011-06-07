#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'school.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);
my $dbh = $ui->dbh; 

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

$ui->tparam(menu_school=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

my %f = $ui->form(qw(type));
my $school_id = $ui->cparam('school_id') || '';

$ui->tparam(degree_stat=>&degree_stat($f{type})) if ($f{type});

if ($f{type} && $school_id) {
    my $user = &user($f{type}, $school_id);
    my $advisors = advisors($f{type}, $school_id);
    $ui->tparam(user=>$user);
    $ui->tparam(advisors=>$advisors);
    $ui->tparam(total=>scalar(@$user));
}

$ui->tparam(has_degree=>&has_degree($auth->uid));

print $ui->output;

sub degree_stat {
    my $type = shift;
    my $sql = qq(select a.full_name as school, a.id, count(*) as count
                 from schools as a , bw_user_degree as b 
                 where a.id=b.school_id && b.type=? 
                 group by a.id order by count desc, school);
    my $rv = $dbh->selectall_hashref($sql, 'id', undef, $type);
    my @rv = map { $$rv{$_}->{current} = $$rv{$_}->{id} eq $school_id ? 1 : 0; $$rv{$_} }
                sort { 
                        $$rv{$a}->{school} cmp $$rv{$b}->{school}
                     }
                    keys %$rv;
    return \@rv;
}

sub user {
    my ($type, $school_id) = @_;
    my $sql = qq(select a.ki, b.name, b.id, b.uid
                 from bw_user_ki as a, bw_xauth_passwd as b, 
                      bw_user_degree as c 
                 where a.uid=b.uid && b.uid=c.uid && c.type=? && c.school_id=?);
    my $rv = $dbh->selectall_hashref($sql, 'id', undef, $type, $school_id);
    my @rv = map { $$rv{$_} }
                sort { $$rv{$a}->{ki} <=> $$rv{$b}->{ki} ||
                       $$rv{$a}->{name} cmp $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub has_degree {
    my $uid = shift;
    my $ki = &ki($uid);
    my $max_ki = &max_ki;
    my $sql = qq(select count(*) from bw_user_degree where uid=?);
    my $rv = $dbh->selectrow_array($sql, undef, $uid);
    my $has_degree = $rv || $max_ki - $ki < 5 ? 1 : 0;
    return $has_degree;
}

sub max_ki {
    my $sql = qq(select max(ki) from bw_user_ki);
    my $rv = $dbh->selectrow_array($sql);
    return $rv;
}

sub ki {
    my $uid = shift;
    my $sql = qq(select ki from bw_user_ki where uid=?);
    my $rv = $dbh->selectrow_array($sql, undef, $uid);
    return $rv;
}

sub advisors {
    my ($type, $school_id) = @_;
    my $sql = qq(select advisors, uid from bw_user_degree where school_id =? && advisors !='' && type=?);
    my $rv = $dbh->selectall_arrayref($sql, undef, $school_id, $type);
    my %advisor;
    foreach my $i (@$rv) {
        push @{ $advisor{ $$i[0] } }, "'u$$i[1]'";
    }
    my @rv = map { { advisors => $_, uids => join(",", @{ $advisor{$_} }) } }
             sort { $a cmp $b } keys %advisor;
    return \@rv;
}
1;
