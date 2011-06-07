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
    print $ui->cgi->header('text/javascript');
    print "var unreadCount = -1";
    exit(1);
}

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

my $id = $auth->id;

my $reset = $ui->cgi->param('reset') || 0;

my $rv = $xb->set_bookmarkset(-uid=>$auth->uid)
    if ($reset);

my $total_articlenum = $xb->get_totalnewarticles(-uid=>$auth->uid);
my $total_commentnum = $xb->get_totalnewcomments(-uid=>$auth->uid);
#my $total_articlenum = $xb->get_totalnewarticles(-uid=>1);
#my $total_commentnum = $xb->get_totalnewcomments(-uid=>1);

$total_articlenum = 0 if ($total_articlenum > 18446744000000000000);
$total_commentnum = 0 if ($total_commentnum > 18446744000000000000);

my $total = 0;
$total = $total_articlenum + $total_commentnum; 

print $ui->cgi->header('text/javascript');
print "var unreadCount = $total";
#print "$total_articlenum ($total_commentnum)";
1;
