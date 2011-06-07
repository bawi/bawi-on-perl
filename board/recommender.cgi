#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::Group;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $q = $ui->cgi;

################################################################################
## main
################################################################################

my ($bid, $aid) 
    = map { $q->param($_) || undef } qw( bid aid );
    
my $uid = $auth->uid || 0;
my $is_root = $uid == 1 ? 1 : 0;

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $skin = $xb->skin || '';

$ui->init(-template=>'recommender.tmpl', -skin=>$skin);
$ui->tparam(HTMLTitle => "추천한 사람");

my $t = $ui->template;
my $allow_recom_user_list = $is_root || ($ui->cfg->AllowRecomUserList && $xb->allow_recom ) || 0;
if ($allow_recom_user_list && $aid && $aid =~ /^\d+$/) {
    my $recom_user_list = $xb->get_recom_user_list(-article_id=>$aid);
    $t->param(recom_user_list=>$recom_user_list);
    my $total = scalar(@$recom_user_list) || 0;
    $t->param(total=>scalar(@$recom_user_list));
    $ui->tparam(nomenu=>1);
} else {
    $ui->msg(qq(You don't have permission to read.));
}

################################################################################

print $ui->output;
1;
