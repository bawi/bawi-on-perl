#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI(-template=>'deluser.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

if ($auth->uid == 1) {
    $ui->tparam(is_root=>1);
    my $uid = $ui->cparam('uid') || '';
    my $del = $ui->cparam('del') || '';
    if ($uid && $uid =~ /^\d+/) {
        my $user = $auth->get_user(-uid=>$uid);
        $ui->tparam(%$user) if $user;
        if ($del && $del eq '1') {
            my $rv = $auth->deluser(-uid=>$uid);
            $ui->msg(qq($$user{name} ($$user{id}) deleted.))
                if ($rv);
        }
    }
} else {
    $ui->msg('Please login as root.');
}

print $ui->output;
1;
