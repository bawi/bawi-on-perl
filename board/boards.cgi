#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use Bawi::Board::Group;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->init(-template=>'boards.tmpl');
$ui->term(qw(T_BOARD T_BOOKMARK T_SAVEBOOKMARKS));
$ui->tparam(HTMLTitle => "게시판");

################################################################################
## main
################################################################################

my $gid = $ui->cparam('gid') || 1;
my $uid = $auth->uid || 0;
my $sort = $ui->cparam('sort') || 'seq';
$sort = $sort =~ /seq|title|days/ ? $sort : 'seq';

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $grp = new Bawi::Board::Group(-gid=>$gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);

my $path_string = join(" &gt; ", map { $_->{title} } @{$grp->get_path});
$ui->tparam(HTMLTitle=>$path_string." 게시판");
$ui->tparam(path=>$grp->get_path);
$ui->tparam(subgroup=>$grp->get_subgroup);

my $bm = $xb->get_bookmarkset(-uid=>$auth->uid);
my %bm;
foreach my $i (@$bm) {
    ++$bm{ $$i{board_id} };
}

my $rv = $xb->get_boardset(-gid=>$gid, -sort=>$sort);

foreach my $i (@$rv) {
    my $bid = $$i{board_id};
    $$i{checked} = 1  if ($bm{ $bid });
    if ($ui->cgi->request_method && $ui->cgi->request_method eq 'POST') {
        if ($ui->cparam("bid$bid") ) {
            #my $xb = new Bawi::Board(-board_id=>$bid);
            $xb->add_new_bookmark(-board_id=>$bid, -uid=>$uid)
                unless ($$i{checked});
            $$i{checked} = 1;
        } else {
            $xb->del_bookmark(-board_id=>$bid, -uid=>$uid);
            $$i{checked} = 0;
        }
    }
}

$ui->tparam(gid=>$gid);

my $half = int( $#{$rv} / 2 );
my @c1 = map { $$rv[$_] } (0..$half);
my @c2 = map { $$rv[$_] } ($half+1 ..$#$rv);
$ui->tparam(boards=>[
   {class=>'first', column=>\@c1},
   {class=>'last',  column=>\@c2},
]);

my $allow_board = $grp->authz(-uid=>$uid, 
                              -ouid=>$grp->gid,
                              -gperm=>$grp->g_board,
                              -mperm=>$grp->m_board,
                              -aperm=>$grp->a_board,
                              );
$ui->tparam(allow_board=>$allow_board);
my $allow_sub = $grp->authz(-uid=>$uid, 
                            -ouid=>$grp->gid,
                            -gperm=>$grp->g_sub,
                            -mperm=>$grp->m_sub,
                            -aperm=>$grp->a_sub,
                            );
$ui->tparam(allow_sub=>$allow_sub);

print $ui->output;
1;
