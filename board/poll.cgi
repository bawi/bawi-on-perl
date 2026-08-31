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
# force numeric ids up front (read.cgi's pattern): both are reflected
# into the xtab link hrefs, so a non-numeric value must die here, not
# ride a MariaDB leading-digit coercion into the rendered page.
$bid = 0 unless ($bid =~ /^\d+$/);
$aid = 0 unless ($aid =~ /^\d+$/);

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
    if ($pid && $pid =~ /^\d+$/ && $aid =~ /^\d+$/) {
        # every pid action (vote, option add, delete) must target a poll
        # of the authorized board/article; ids lifted from another
        # (possibly private) board do nothing.
        my $ps = $xb->get_pollset(-article_id=>$aid, -uid=>$uid, -poll_id=>$pid);
        my $poll = $ps && @$ps ? $$ps[0] : undef;
        undef $poll unless ($poll && $$poll{board_id} == $bid);
        my $opt_text = $ui->cparam('opt_text');
        $opt_text = '' unless (defined $opt_text);
        $opt_text =~ s/^\s+//g;
        $opt_text =~ s/\s+$//g;
        $opt_text =~ s/\s+/ /g;
        if ($poll && $opt_text ne '') {
            # a voter-supplied option; takes precedence over oid.
            # cap at 100 chars without splitting a utf-8 sequence
            # (the form maxlength can be bypassed).
            my @char = $opt_text =~ /([\x00-\x7f]|[\xc0-\xff][\x80-\xbf]+)/g;
            $opt_text = join('', @char[0 .. 99]) if (@char > 100);
            # _pollset.tmpl prints opt unescaped, so escape at insert.
            $opt_text = $ui->cgi->escapeHTML($opt_text);
            # allow_vote covers both 'still open' and 'has not voted yet'.
            if ($$poll{allow_user_opt} && $$poll{allow_vote}) {
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
        } elsif ($poll) {
            my $ans = $xb->add_ans(-poll_id=>$pid, -uid=>$uid, -opt_id=>$oid)
                if ($oid && $oid =~ /^\d+$/);
        }
        # is_owner: the delete endpoint historically trusted the UI to
        # show the button only to the owner; enforce it server-side.
        my $rv = $xb->del_poll(-poll_id=>$pid, -article_id=>$aid)
            if ($poll && $$poll{is_owner} && $del && $del eq '1');
    }
    my $pollset = $xb->get_pollset(-article_id=>$aid, -uid=>$uid);
    $ui->tparam(HTMLTitle=>$xb->title." (".$xb->id.")");
    $ui->tparam(pollset=>$pollset);
    $ui->tparam(article_id=>$aid);
    $ui->tparam(board_id=>$bid);
    # cross-tab entry links: every poll pair plus each poll x 기수 (the
    # ki axis is what gives a single-poll article a cross-tab at all).
    # Plain GET links, no script -- the 교차분석 link _pollset.tmpl
    # renders inside read.cgi's article page navigates here. Tally-
    # hidden election polls are skipped: their cross-tabs are refused
    # server-side, and a link into a silent refusal is the blank the
    # gated flag was invented to kill.
    if ($pollset && @$pollset) {
        my @xlink;
        foreach my $i (0 .. $#$pollset) {
            next if (Bawi::Board::is_tally_hidden($$pollset[$i]{poll_id}));
            foreach my $j ($i + 1 .. $#$pollset) {
                next if (Bawi::Board::is_tally_hidden($$pollset[$j]{poll_id}));
                push @xlink,
                     { label=>sprintf('%d × %d', $i + 1, $j + 1),
                       href=>qq(poll.cgi?bid=$bid;aid=$aid;mode=xtab)
                            .qq(;p1=$$pollset[$i]{poll_id};p2=$$pollset[$j]{poll_id}) };
            }
            push @xlink,
                 { label=>sprintf('%d × 기수', $i + 1),
                   href=>qq(poll.cgi?bid=$bid;aid=$aid;mode=xtab)
                        .qq(;p1=$$pollset[$i]{poll_id};p2=ki) };
        }
        $ui->tparam(xtab_links=>\@xlink);
    }
    if ($mode eq 'xtab') {
        my ($p1, $p2) = map { $ui->cparam($_) || '' } qw(p1 p2);
        my $xtab;
        if ($p1 =~ /^\d+$/ && $bid =~ /^\d+$/ && $aid =~ /^\d+$/) {
            if ($p2 eq 'ki') {
                $xtab = $xb->get_poll_ki_xtab(-poll_id=>$p1, -board_id=>$bid,
                                              -article_id=>$aid, -uid=>$uid);
                $ui->tparam(xtab_ki=>1) if ($xtab);
            } elsif ($p2 =~ /^\d+$/) {
                $xtab = $xb->get_poll_xtab(-poll_id1=>$p1, -poll_id2=>$p2,
                                           -board_id=>$bid, -article_id=>$aid,
                                           -uid=>$uid);
            }
        }
        if ($xtab) {
            $ui->tparam(xtab=>1);
            $ui->tparam(xtab_poll1=>$$xtab{poll1});
            $ui->tparam(xtab_poll2=>$$xtab{poll2});
            if ($$xtab{gated}) {
                $ui->tparam(xtab_gated=>1);
            } elsif ($$xtab{suppressed}) {
                $ui->tparam(xtab_suppressed=>1);
            } else {
                # loop params must never be set to a scalar/undef --
                # HTML::Template dies on it
                $ui->tparam(xtab_cols=>$$xtab{cols});
                $ui->tparam(xtab_rows=>$$xtab{rows});
                $ui->tparam(xtab_n=>$$xtab{n});
                $ui->tparam(xtab_colspan=>$$xtab{colspan});
            }
        }
    }
    $ui->tparam(ajax=>1) if $mode eq "ajax";

} else {
    $ui->msg('No board is selected.');
}

print $ui->output;
1;
