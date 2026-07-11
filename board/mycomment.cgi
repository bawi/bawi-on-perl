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

my $DBH = $ui->dbh;
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

my $board_id = $q->param('bid') || 0;
my $sql;
my $rv;

if ($board_id) {
  $sql = qq(SELECT count(*) FROM bw_xboard_comment WHERE uid=? && board_id=?);
  $rv = $DBH->selectrow_array($sql, undef, $uid, $board_id);
} else {
  $sql = qq(SELECT count(*) FROM bw_xboard_comment WHERE uid=?);
  $rv = $DBH->selectrow_array($sql, undef, $uid);
}

my $articles = $rv;
my $article_per_page = 16;
my $page_per_page = 10;
my $tot_page = int ($articles / $article_per_page);
++$tot_page if ($articles % $article_per_page);
$tot_page = 1 if ($tot_page < 1);
my $p = $q->param('p');
my $page = $p;
$page = $tot_page unless ($page && $page =~ /^\d+$/ && $page <= $tot_page);

my $start_limit = ($tot_page - $page) * $article_per_page;

my $start = $page % $page_per_page ?
    		( int($page / $page_per_page) + 1 ) * $page_per_page :
    		int($page / $page_per_page) * $page_per_page;
$start = $start > $tot_page ? $tot_page : $start;
my $end = $start - $page_per_page + 1;
$end = 1 if ($end < 1);
my @pages;
for (my $i = $start; $i >= $end; $i--) {
	my $current = $page == $i ? 1 : 0;
	push @pages, { page=>$i,
    	           current=>$current,
                 };
}
my $next_page = $end - 1 if ($end - 1 > 0);
my $prev_page = $start + 1 if ($start + 1 <= $tot_page);
my $first_page = 1 if ($page > $page_per_page);
my $last_page = $tot_page if ($page <= $tot_page - $page_per_page + 1);

$ui->init(-template=>'mycomment.tmpl');
my $t = $ui->template;
$t->param(HTMLTitle=>"나의 짧은답글 보기 ".$name."(".$id.")");
$t->param(name=>$name);
$t->param(id=>$id);
$t->param(next_page=>$next_page);
$t->param(prev_page=>$prev_page);
$t->param(first_page=>$first_page);
$t->param(last_page=>$last_page);
$t->param(pages=>\@pages);
$t->param(p=>$p);
$t->param(total=>$articles);
# cur_page = this my-comments listing page (reverse-numbered like the board).
# The delete link routes through comment.cgi, which redirects to
# mycomment.cgi?p=<this>, so it must carry the listing page, NOT the per-row
# board page (that one is `page`, used only by the read link).
# But comment.cgi's redirect drops the bid, so when this listing is itself
# bid-filtered the filtered page number would be applied to the UNFILTERED
# listing (a different, usually larger, page space) and land on the wrong
# page. In the filtered case emit an empty p instead, which mycomment.cgi
# then clamps to the newest page — the pre-existing behaviour for that flow.
$t->param(cur_page=>$board_id ? '' : $page);

# The board list page (read.cgi's p=) the comment's article appears on —
# pages are reverse-numbered (tot_page = newest), matching get_tot_page/
# get_start in Bawi::Board. The templates always forwarded p=<tmpl_var page>,
# but no page column was ever selected, so the link carried an empty p.
# CAST ... AS SIGNED: c.articles/c.article_per_page are UNSIGNED, so if the
# counter has drifted low the CEIL-FLOOR difference goes negative and an
# unsigned subtraction raises ER_DATA_OUT_OF_RANGE (1690) instead of letting
# GREATEST clamp it — the SIGNED cast keeps the drift case a clamp, not a 500.
my $board_page = qq(IF(c.article_per_page > 0,
                       GREATEST(1, CAST(CEIL(c.articles / c.article_per_page) AS SIGNED) -
                                   CAST(FLOOR((SELECT count(*) FROM bw_xboard_header as h
                                          WHERE h.board_id=a.board_id && h.article_id > a.article_id)
                                         / c.article_per_page) AS SIGNED)),
                       1) as page);

if ($board_id) {
  $sql = qq(SELECT a.board_id as board_id, a.article_id as article_id, a.comment_id as comment_id,                  
                 a.comment_no as comment_no, b.title as article_title,                  
                 REPLACE(a.body, '<', '&lt;') as comment, a.uid as uid, a.id as id, a.name as name,                  
                 IF( a.created + INTERVAL 180 DAY > now(),                      
                     DATE_FORMAT(a.created, '%m/%d'),
                     DATE_FORMAT(a.created, '%y/%m/%d') ) as created,
                 DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                 $board_page,
                 c.title as board_title
                 FROM bw_xboard_comment as a
                 LEFT JOIN bw_xboard_header as b ON a.article_id=b.article_id
                 LEFT JOIN bw_xboard_board as c ON a.board_id=c.board_id
                 WHERE a.uid=? && a.board_id=?
                 ORDER BY a.comment_id DESC
				 LIMIT $start_limit, $article_per_page);
           
  $rv = $DBH->selectall_hashref($sql, "comment_id", undef, $uid, $board_id);
  $t->param(url=>"mycomment.cgi?bid=$board_id&");
} else {
  $sql = qq(SELECT a.board_id as board_id, a.article_id as article_id, a.comment_id as comment_id,                  
                 a.comment_no as comment_no, b.title as article_title,                  
                 REPLACE(a.body, '<', '&lt;') as comment, a.uid as uid, a.id as id, a.name as name,                  
                 IF( a.created + INTERVAL 180 DAY > now(),                      
                     DATE_FORMAT(a.created, '%m/%d'),
                     DATE_FORMAT(a.created, '%y/%m/%d') ) as created,
                 DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                 $board_page,
                 c.title as board_title
                 FROM bw_xboard_comment as a
                 LEFT JOIN bw_xboard_header as b ON a.article_id=b.article_id
                 LEFT JOIN bw_xboard_board as c ON a.board_id=c.board_id
                 WHERE a.uid=?
                 ORDER BY a.comment_id DESC
				 LIMIT $start_limit, $article_per_page);
           
  $rv = $DBH->selectall_hashref($sql, "comment_id", undef, $uid);
  $t->param(url=>"mycomment.cgi?");
}
my @rv = map { $rv->{$_} } sort {$b <=> $a} keys %$rv;
$t->param(list=>\@rv);

# navigation
print $ui->output;

1;
