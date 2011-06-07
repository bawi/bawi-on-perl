#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-template=>'hot.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
  print $auth->login_page($ui->cgiurl);
  exit(1);
}

$ui->term(qw(T_BOOKMARK T_PREV T_NEXT T_NEWARTICLES T_IMGLIST T_ARTICLELIST T_WRITE T_THREAD T_REPLY T_EDIT T_DELETE T_TITLE T_NAME T_ID T_ADDBOOKMARK T_DELBOOKMARK T_SCRAP T_SCRAPPED T_READ T_RECOMMEND T_RECOMMENDED T_BOARDCFG T_ADDNOTICE T_DELETENOTICE T_NEWCOMMENTS T_COMMENT T_SAVE T_RESET));

$ui->tparam(HTMLTitle=>"화제의 글");

my $top = 100;
my $dbh = $ui->dbh; 

my $hot = qq(
select a.title as board_title, b.board_id, b.article_id, b.title, b.id, b.name, 
       date_format(b.created, '%m/%d') as created, b.count, b.recom, 
       round(b.count * 0.01 + b.recom * 3 + 10 * b.recom * 100 / ( b.count ) 
           + b.comments * 0.3 ) as score
from bw_xboard_board as a, bw_xboard_stat_article as b
where a.board_id=b.board_id && b.ki > 2 
order by score desc limit $top);
my $hot_stat = $dbh->selectall_hashref($hot, 'article_id');
my @hot_stat = map { $$hot_stat{$_} } sort { $$hot_stat{$b}->{score} <=> $$hot_stat{$a}->{score} } keys %$hot_stat;
$ui->tparam(list=>\@hot_stat);

################################################################################

print $ui->output;
1;
