#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;

my $ui = new Bawi::Board::UI(-template=>'test.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->term(qw(T_BOARD T_WRITE T_TITLE T_BODY T_FILE T_POLL T_OPTION T_SAVE));
$ui->tparam(allow_write=>1);
$ui->tparam(allow_attach=>1);

#my $sql = qq(select poll_id, board_id, article_id from bw_xboard_poll group by board_id, article_id order by poll_id desc);
#my $rv = $ui->dbh->selectall_hashref($sql, 'poll_id');
#my @rv = sort { $b->{poll_id} <=> $a->{poll_id} } map { $rv->{$_} } keys %$rv;
#$ui->tparam(list=>\@rv);

print $ui->output;
1;
