#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use Digest::MD5 qw(md5_hex);

my $ui = new Bawi::Board::UI( -template=>'bookmark.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $mobile = Bawi::Board::UI::is_mobile_device;

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

$ui->term(qw(T_BOOKMARK T_BOARD T_SCRAPBOOK T_RESET T_NEWARTICLES));
$ui->tparam(HTMLTitle => "즐겨찾기");

my $id = $auth->id;
$ui->tparam(id=>$id);

$ui->tparam(is_admin=>$auth->is_admin);

my $dev = "";
$dev = $ENV{SERVER_NAME} if (exists $ENV{SERVER_NAME} and ($ENV{SERVER_NAME} ne "www.bawi.org"));
$ui->tparam(dev=>$dev);

my $reset = $ui->cgi->param('reset') || 0;
my $rv = $xb->set_bookmarkset(-uid=>$auth->uid)
    if ($reset);

my $bm = $xb->get_bookmarkset(-uid=>$auth->uid);
if ($bm) {
    my @bm
      = sort { ( ($a->{new_articles} or $a->{new_comments}) ? 1 : 2)
               <=> 
               ( ($b->{new_articles} or $b->{new_comments}) ? 1 : 2)
             } @{$bm};
    #if ($mobile) {
    #  @bm = @sorted_by_new;
    #} else {
    
    my $half = int( $#{$bm} / 2 );
    my @c1 = map { $bm[$_] } (0..$half);
    my @c2 = map { $bm[$_] } ($half+1 ..$#bm);

    $ui->tparam(bookmark=>[
        {class=>'first', column=>\@c1},
        {class=>'last',  column=>\@c2},
    ]);
    my $uid = $auth->uid;
    my $code = md5_hex($uid, $ui->cfg->DBPasswd, $ui->cfg->DBName, $ui->cfg->DBUser, $ui->cfg->AttachDir);
    $ui->tparam(code=>$code);
    $ui->tparam(uid=>$uid);
} else {
    $ui->msg('Bookmark your favorite boards from the board list.');
}

print $ui->output;

1;
