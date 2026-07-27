#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use Bawi::Board::Group;

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
    # same read gate as read.cgi: login alone must not open a private
    # board's polls (votes before, joint distributions now).
    my $grp = new Bawi::Board::Group(-gid=>$xb->gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
    my $allow_read = $grp->authz(-uid   => $uid,
                                 -ouid  => $xb->uid,
                                 -gperm => $xb->g_read,
                                 -mperm => $xb->m_read,
                                 -aperm => $xb->a_read);
    unless ($allow_read) {
        $ui->msg('Permission denied.');
        print $ui->output;
        exit (1);
    }
    if ($pid) {
        my $opt_text = $ui->cparam('opt_text');
        $opt_text = '' unless (defined $opt_text);
        $opt_text =~ s/^\s+//g;
        $opt_text =~ s/\s+$//g;
        $opt_text =~ s/\s+/ /g;
        if ($opt_text ne '') {
            # a voter-supplied option; takes precedence over oid.
            # cap at 100 chars without splitting a utf-8 sequence
            # (the form maxlength can be bypassed).
            my @char = $opt_text =~ /([\x00-\x7f]|[\xc0-\xff][\x80-\xbf]+)/g;
            $opt_text = join('', @char[0 .. 99]) if (@char > 100);
            # _pollset.tmpl prints opt unescaped, so escape at insert.
            $opt_text = $ui->cgi->escapeHTML($opt_text);
            my $ps = $xb->get_pollset(-article_id=>$aid, -uid=>$uid, -poll_id=>$pid);
            my $poll = $ps && @$ps ? $$ps[0] : undef;
            # allow_vote covers both 'still open' and 'has not voted yet'.
            if ($poll && $$poll{allow_user_opt} && $$poll{allow_vote}) {
                my $optset = $$poll{optset} || [];
                my ($dup) = grep { $$_{opt} eq $opt_text } @$optset;
                # two voters adding the same text at once can still insert
                # a duplicate option; rare and harmless, so no lock here.
                my $new_oid = $dup ? $$dup{opt_id}
                            : @$optset < 30 ? $xb->add_opt(-poll_id=>$pid, -opt=>$opt_text)
                            : 0;
                my $ans = $xb->add_ans(-poll_id=>$pid, -uid=>$uid, -opt_id=>$new_oid)
                    if ($new_oid);
            }
        } else {
            my $ans = $xb->add_ans(-poll_id=>$pid, -uid=>$uid, -opt_id=>$oid)
                if ($oid && $oid =~ /^\d+$/);
        }
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
            $ui->tparam(xtab_n_hidden=>$$xtab{n_hidden});
            $ui->tparam(xtab_colspan=>$$xtab{colspan});
        }
    }
    $ui->tparam(ajax=>1) if $mode eq "ajax";

} else {
    $ui->msg('No board is selected.');
}

print $ui->output;
1;
