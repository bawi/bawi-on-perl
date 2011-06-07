#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use Bawi::Board::Group;
use Digest::MD5 qw(md5_hex);

my $ui = new Bawi::Board::UI(-template=>'bookmarkgrp.tmpl');;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $q = $ui->cgi;

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $grp = new Bawi::Board::Group(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

$ui->term(qw(T_BOOKMARK T_BOARD T_SCRAPBOOK T_RESET T_NEWARTICLES));
$ui->tparam(HTMLTitle => "즐겨찾기(그룹)");
$ui->tparam(is_admin=>$auth->is_admin);
$ui->tparam(id=>$auth->id);
my $dev = "";
$dev = $ENV{SERVER_NAME} if (exists $ENV{SERVER_NAME} and ($ENV{SERVER_NAME} ne "www.bawi.org"));
$ui->tparam(dev=>$dev);

my $reset = $ui->cgi->param('reset') || 0;
my $rv = $xb->set_bookmarkset(-uid=>$auth->uid)
    if ($reset);
################################################################################
my $gid = $q->param('gid');
my $ex_gid = $q->param('ex_gid');

my $bm = $xb->get_bookmarkset_by_group(-uid=>$auth->uid,-gid=>$gid,-ex_gid=>$ex_gid);
if ($bm) {
    $$bm[0]{class} = 'first';
    $$bm[$#$bm]{class} = 'last';
    foreach my $i (@$bm) {
        foreach my $j (@{$$i{column}}) {
            $$j{path} = $grp->get_path(-gid=>$$j{path});
        }
    }
    $ui->tparam(bookmark=>$bm);
    my $uid = $auth->uid;
    my $code = md5_hex($uid, $ui->cfg->DBPasswd, $ui->cfg->DBName, $ui->cfg->DBUser, $ui->cfg->AttachDir);
    $ui->tparam(code=>$code);
    $ui->tparam(uid=>$uid);
} else {
    $ui->msg('Bookmark your favorite boards from the board list.');
}

print $ui->output;
1;
