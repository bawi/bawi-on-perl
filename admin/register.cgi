#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-main_dir=>'admin');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth_admin) {
    print $auth->access_denied($ui->cgiurl);
    exit(1);
}
$ui->init(-template=>'register.tmpl');
my $dbh = $ui->dbh;

my $admin = $auth->name;

my $status = $ui->cparam('s') || '';
$ui->tparam(list=>&new_users($status)) if $status;

my ($stat, $total) = &stat;
$ui->tparam(stat=>$stat);
$ui->tparam(total=>$total);

$ui->tparam(same_name=>&same_name);

print $ui->output;

sub new_users {
    my $status = shift;

    my $where = '';
    if ($status && $status =~ /applied|recommended|rejected|ignored|done/) {
        $where = qq(where status='$status');
    }
    my $sql = qq(select no, id, name, email, birth, ki, affiliation, recom_id,
                        recom_passwd, status, date_format(created, "%Y-%m-%d") 
                        as created
                 from bw_xauth_new_passwd $where);
    my $rv = $dbh->selectall_hashref($sql, 'no');
    my @rv = map { $$rv{$_} }
                sort { 
                        $$rv{$a}->{ki} <=> $$rv{$b}->{ki} ||
                        $$rv{$a}->{name} cmp $$rv{$b}->{name} ||
                        $$rv{$a}->{created} cmp $$rv{$b}->{created}
                     }
                    keys %$rv;
    return \@rv;
}

sub stat {
    my $sql = qq(select status, count(*) as count from bw_xauth_new_passwd group by status);
    my $rv = $dbh->selectall_hashref($sql, 'status');
    my @rv = map { $$rv{$_} }
                sort { 
                        $$rv{$a}->{status} cmp $$rv{$b}->{status}
                     }
                    keys %$rv;
    my $total = 0;
    foreach my $i (@rv) {
        $total += $$i{count};
    }
    return (\@rv, $total);
}

sub same_name {
    my $sql = qq(select ki, name, count(*) as count from bw_xauth_new_passwd group by ki, name order by count desc, ki, name limit 4;);
    my $rv = $dbh->selectall_arrayref($sql);
    my @rv = map { {
                    ki => $$_[0],
                    name => $$_[1],
                    count => $$_[2],
                 } } @$rv;
    return \@rv;
}
1;

