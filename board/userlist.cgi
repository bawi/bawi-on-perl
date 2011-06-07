#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;

my $ui = new Bawi::Board::UI(-template=>'userlist.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->tparam(HTMLTitle => "회원");
my $t = $ui->template;

my $page = $ui->cparam('p') || 0;
my $sort = $ui->cparam('sort') || 'accessed';
my $order = $ui->cparam('order') || 0;

my $is_root = $auth->uid == 1 ? 1 : 0;
my $AllowUserList = $ui->cfg->AllowUserList || $is_root ? 1 : 0;
if ($AllowUserList) {
    $t->param(is_root=>$is_root);
    $t->param(AllowUserList=>$AllowUserList);
    my $userlist = $auth->userlist(-page    => $page, 
                                   -sort    => $sort, 
                                   -order   => $order);
    my @userlist = map { $$_{is_root} = $is_root; $_ } @$userlist;
    $t->param(userlist=>$userlist);
    $t->param(%{ $auth->get_pagenav(-page   => $page, 
                                    -sort   => $sort,
                                    -order  => $order) });
} else {
    $ui->msg('Please login as root.');
}

print $ui->output;
1;
