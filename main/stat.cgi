#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

################################################################################
## main
################################################################################
$ui->init(-template=>'stat.tmpl');
my $t =  $ui->template;

my $top = 30;
$t->param(top=>$top);

my $dbh = $ui->dbh; 

my $board = qq(
select a.title, b.board_id, b.counts, b.articles, b.comments, b.recoms,
       round(b.counts / b.articles) as ave_counts, 
       round(b.comments / b.articles) as ave_comments, 
       round(b.recoms / b.articles, 1) as ave_recoms, 
       round(b.articles * 3 + b.counts * 0.1 + b.recoms * 3 + 
             (b.counts + b.comments * 5 + b.recoms * 50) / b.articles) as score
from bw_xboard_board as a, bw_xboard_stat_board as b
where a.board_id=b.board_id order by score desc limit $top);

my $board_stat = $dbh->selectall_hashref($board, 'board_id');
my @board_stat = map { $$board_stat{$_} } sort { $$board_stat{$b}->{score} <=> $$board_stat{$a}->{score} } keys %$board_stat;
$t->param(board_stat=>\@board_stat);

my $user = qq(
select b.ki, a.id, a.name, a.articles, a.counts, a.comments, a.recoms, 
       round(a.counts / a.articles) as ave_counts, 
       round(a.comments / a.articles) as ave_comments, 
       round(a.recoms / a.articles, 1) as ave_recoms, 
       round(a.articles * 5 + a.recoms * 5 + a.counts * 0.1 + (a.counts * 1+ a.comments* 5 + a.recoms * 50) / a.articles) as score 
from bw_xboard_stat_user as a, bw_user_ki as b, bw_xauth_passwd as c
where a.id = left(c.id,10) && c.uid=b.uid order by score desc limit $top); 

my $user_stat = $dbh->selectall_hashref($user, 'id');
my @user_stat = map { $$user_stat{$_} } sort { $$user_stat{$b}->{score} <=> $$user_stat{$a}->{score} } keys %$user_stat;
$t->param(user_stat=>\@user_stat);

my $gbook = $dbh->selectall_arrayref(qq(
select a.ki, b.name, b.id, b.uid, count(distinct c.guest_uid) as count, count(c.guest_uid) as articles
from bw_user_ki as a, bw_xauth_passwd as b, bw_user_gbook as c
where a.uid=b.uid && b.uid=c.uid && a.ki > 0 && c.created > DATE_SUB(NOW(), INTERVAL 24 HOUR)
group by b.id order by count desc, articles desc, a.ki, b.name limit 30));
my @gbook = map { { ki=>$$_[0], name=>$$_[1], id=>$$_[2], uid=>$$_[3], count=>$$_[4], articles=>$$_[5] } } @$gbook;
$t->param(gbook_stat=>\@gbook);
################################################################################

print $ui->output;
1;
