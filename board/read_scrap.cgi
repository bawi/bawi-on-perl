#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;

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
my ($uid, $id, $name, $session_key);
if ($auth->auth) {
    ($uid, $id, $name, $session_key) = ($auth->uid, $auth->id, $auth->name, $auth->session_key);
} else {
    ($uid, $id, $name, $session_key) = (0, 'guest', 'guest', '');
}
#my ($uid, $id, $name) = ($auth->uid, $auth->id, $auth->name);
my ($bid, $aid, $tno, $p, $a, $img) = 
    map { $q->param($_) || undef } qw( bid aid tno p a img );
$bid = 0 unless (defined $bid && $bid =~ /^\d+$/);

$p = 0 unless ($p && $p =~ /^\d+$/);
my $xb = new Bawi::Board(-cfg=>$ui->cfg,
                          -page=>$p,
                          -uid=>$uid,
                          -session_key => $session_key,
                          -dbh=>$ui->dbh);

$ui->init(-template=>'read_scrap.tmpl');
$ui->term(qw(T_BOOKMARK T_PREV T_NEXT T_NEWARTICLES T_IMGLIST T_ARTICLELIST T_WRITE T_THREAD T_REPLY T_EDIT T_DELETE T_TITLE T_NAME T_ID T_ADDBOOKMARK T_DELBOOKMARK T_SCRAP T_SCRAPPED T_READ T_RECOMMEND T_RECOMMENDED T_BOARDCFG T_ADDNOTICE T_DELETENOTICE T_NEWCOMMENTS T_COMMENT T_SAVE T_RESET));
my $t = $ui->template;
$t->param(HTMLTitle=>$xb->title." (".$auth->id.")"); # note that the ID is set to user id here.
$t->param(board_title=>$xb->title);
$t->param(img=>$img);

################################################################################
# article

my $article = $xb->get_article(-board_id=>$bid, -article_id=>$aid)
    if ($aid && $aid =~ /^\d+$/);

if ($article) {
    $$article{body} = $xb->format_article(-body=>$$article{body});
    $$article{comment} = $xb->get_commentset(-board_id=>$bid,
                                             -article_id=>$aid,
                                             -uid=>$uid);
    $$article{attach} = $xb->get_attachset(-article_id=>$aid);
    delete $$article{uid} unless ($$article{uid} == $uid);
    $t->param(article_set=>[{ article=>[$article] }]);
}

################################################################################
# thread

my $thread = $xb->get_thread(-thread_no=>$tno)
    if ($tno && $tno =~ /^\d+$/);

if ($thread) {
    foreach my $i (@$thread) {
        $$i{body} = $xb->format_article(-body=>$$i{body});
        $$i{comment} = $xb->get_commentset(-article_id=>$$i{article_id}, -uid=>$uid),
        $$i{attach} = $xb->get_attachset(-article_id=>$$i{article_id});
        delete $$i{uid} unless ($uid && $$i{uid} == $uid);
    }
    $t->param(article_set=>[{ article=>$thread }]);
    $t->param(total_thread=>$#{$thread} + 1);
}
    
################################################################################
# article list

my $al;
#if ($bid > 0) {
#	$al = $xb->get_scrap_articlelist_by_board(-uid=>$uid, -bid=>$bid);
#} else {
	$al = $xb->get_scrap_articlelist(-uid=>$uid);
#}
$t->param(list=>$al);

################################################################################
# navigation 

$t->param(%{ $xb->get_pagenav });

################################################################################

print $ui->output;
1;
