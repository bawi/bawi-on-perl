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
    $ui->tparam(board_id=>$bid);
    $ui->tparam(xtab_form=>1) if ($pollset && @$pollset > 1);
    if ($mode eq 'xtab') {
        my ($p1, $p2) = map { $ui->cparam($_) || '' } qw(p1 p2);
        my $xtab;
        $xtab = $xb->get_poll_xtab(-poll_id1=>$p1, -poll_id2=>$p2)
            if ($p1 =~ /^\d+$/ && $p2 =~ /^\d+$/);
        if ($xtab) {
            $ui->tparam(xtab=>1);
            $ui->tparam(xtab_poll1=>$$xtab{poll1});
            $ui->tparam(xtab_poll2=>$$xtab{poll2});
            $ui->tparam(xtab_cols=>$$xtab{cols});
            $ui->tparam(xtab_rows=>$$xtab{rows});
            $ui->tparam(xtab_n=>$$xtab{n});
            $ui->tparam(xtab_colspan=>$$xtab{colspan});
        }
    }
    $ui->tparam(ajax=>1) if $mode eq "ajax";

} else {
    $ui->msg('No board is selected.');
}

print $ui->output;
1;
