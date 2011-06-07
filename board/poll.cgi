#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI(-template=>'poll.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $t = $ui->template;

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}
my ($bid, $aid, $pid, $oid, $del, $mode)
    = map { $ui->cparam($_) || '' } qw(bid aid pid oid del mode);

if ($bid && $aid) {
    my $uid = $auth->uid;
    my $xb = new Bawi::Board(-cfg=>$ui->cfg, 
                              -board_id=>$bid, 
                              -dbh=>$ui->dbh);
    if ($pid) {
        my $ans = $xb->add_ans(-poll_id=>$pid, -uid=>$uid, -opt_id=>$oid)
            if ($oid && $oid =~ /^\d+$/);
        my $rv = $xb->del_poll(-poll_id=>$pid, -article_id=>$aid)
            if ($del && $del eq '1');
    }
    my $pollset = $xb->get_pollset(-article_id=>$aid, -uid=>$uid);
    $ui->tparam(HTMLTitle=>$xb->title." (".$xb->id.")");
    $ui->tparam(pollset=>$pollset);
    $ui->tparam(article_id=>$aid);
    $ui->tparam(ajax=>1) if $mode eq "ajax";

} else {
    $ui->msg('No board is selected.');
}

print $ui->output;
1;
