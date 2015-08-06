#!/usr/bin/perl -w
use Benchmark;
my $t0 = new Benchmark;

use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-template => 'news.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

my @l = localtime(time);
my $title = sprintf("대문 %d월%d일 %d시%d분", $l[4]+1,$l[3],$l[2],$l[1]);
$ui->tparam(HTMLTitle=>$title);

my $dev = ""; $dev = $ENV{SERVER_NAME};
$dev = $ENV{SERVER_NAME} if (exists $ENV{SERVER_NAME} and ($ENV{SERVER_NAME} ne "www.bawi.org"));
$ui->tparam(dev=>$dev);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}
my $q = $ui->cgi;
$ui->tparam(id=>$auth->id);
$ui->tparam(is_admin=>$auth->is_admin);
################################################################################
## main
################################################################################

#$ui->init(-template=>'news.tmpl', -path=>"skin/bawi");
my $t = $ui->template;
my $dbh = $ui->dbh; 
my $user_ki = $dbh->selectrow_array('select ki from bw_user_ki where uid = '.$auth->{uid});

my $sql;
# title only: 결혼합니다(638;30), 부고(637;5), 모입니다(679;7), 구인/구직(8;7)
# title only in banner: 동창소식(326;7), 동창회공지(987;7)
# title + body: article stat
# birthday, user/board stats, new boards

# 게시판 이름, bid, 대문 게시 기간 (일), 제목 길이 (byte)
my @boards = (
    ['서비스 공지',  990,  7, 32],
    ['부고 (訃告)',  637,  7, 32],
    ['결혼합니다!',  638, 30, 32],
    ['아기가 태어났습니다!', 1041, 14, 32],
    ['모입니다!',    679, 14, 32],
    ['구인/구직',      8,  7, 30],
    ['벼룩시장',       9,  7, 30],
    ['동창회 공지',  987,  7, 100],
    ['동창소식',     326,  7, 100],
);
foreach my $i (@boards) {
    my $bid = $$i[1];
    my $day = $$i[2];
    my $length = $$i[3];
    my $sql = qq(
select h.board_id, h.title, h.article_id
from bw_xboard_header h
     left join bw_xboard_notice n
     on h.board_id = n.board_id and h.article_id = n.article_id
where ( h.board_id= ? &&
        h.created > date_sub(now(), interval ? day) &&
        n.article_id is null )   
   or ( h.board_id= ? &&
        h.board_id = n.board_id &&
        h.article_id = n.article_id )
limit 30
    );
    my $rv = $dbh->selectall_hashref($sql, 'article_id', undef, $bid, $day, $bid );
    my @rv = map { $$rv{$_} }
               grep { $$rv{$_}->{title} !~ m/###/ }
                 sort { $b <=> $a }
                   keys %$rv;
    if ($bid == 638) { # 결혼합니다
        my $m = (localtime)[4] + 1;
        my $d = (localtime)[3];
        @rv = map { 
                    $_->{title} =~ s/(\d{1,3}):(\d{1,3})/$1시 $2분/g;
                    $_->{title} =~ s/요일|오후|오전|정오|낮|저녁|,|:|200\d\.|\[|\]|결혼\S+|\.\.+|00분|//g; 
                    $_->{title} =~ s/\s*30분/반/g; 
                    $_->{title} =~ s/pm|am/시/g; 
                    $_->{title} =~ s/(\d+기)\S+/$1/g; 
                    $_->{title} =~ s/日/일/g; 
                    $_->{title} =~ s/ (월|화|수|목|금|토|일) / \($1\) /g; 
                    $_->{title} =~ s/(\S+)(\(\S+\))/$1 $2/g; 
                    $_->{title} =~ s/(\d{1,3})\.(\d{1,3})\.*/$1월 $2일/g; 
                    $_->{title} =~ s/(\d{1,3})월(\d{1,3})일/$1월 $2일/g;
                    $_ 
                  } @rv;
        my @rv2;
        foreach my $i (@rv) {
            if ($i->{title} =~ /(\d{1,3})월\s+(\d{1,3})일/) {
                push @rv2, $i
                    if ( ($1 - $m == 1) || ($m - $1 == 11) || ($m == $1 && $2 >= $d));
            }
        }
        @rv = map { delete $_->{key}; $_ } 
                  sort {
                      $a->{key} cmp $b->{key} ||
                      $a->{title} cmp $b->{title}
                  }
                  map { 
                      $_->{title} =~ /(\d{1,3})월\s+(\d{1,3})일/;
                      my $key = sprintf("%02d%02d", $1, $2);
                      ## 1월 문제 - 땜방하기.. linusben
                      if( $key =~ /^01([0-9]+)/ ) { $key = '13'.$1; }
                      $_->{key} = $key;
                      $_;
                  } @rv2;
    } elsif ($bid == 1041) { # 아기가 태어났습니다
        my @rv2;
        foreach my $i (@rv) {
            push @rv2, $i if ($i->{title} =~ /득남|득녀/);
        }
        @rv = @rv2;
    } elsif ($bid == 8) { # 구인/구직
        my @rv2;
        foreach my $i (@rv) {
            push @rv2, $i
                if ($i->{title} !~ /구했|완료|마감/ && $i->{title} =~ /구인|구직/);
        }
        @rv = @rv2;
    } elsif ($bid == 9) { # 벼룩시장
        my @rv2;
        foreach my $i (@rv) {
            push @rv2, $i
                if ($i->{title} !~ /구했|완료|마감/ && $i->{title} =~ /^\[(삽니다|팝니다|드립니다|구합니다)\]/);
        }
        @rv = @rv2;
    }
    @rv = map { $_->{title} = $ui->substrk2($_->{title}, $length); $_ } @rv;
    push @$i, \@rv;
}

my @panel;
foreach my $i (@boards[0..6]) {
    push @panel, { section => $$i[0], board_id => $$i[1], days => $$i[2], titles => $$i[4] };
}
$t->param(panel=>\@panel);

my @box;
foreach my $i (@boards[7..8]) {
    push @box, { section => $$i[0], board_id => $$i[1], days => $$i[2], titles => $$i[4] }
        if scalar @{$$i[4]} > 0;
}
$t->param(box=>\@box);

my $hot = qq(
select a.title as board_title, b.board_id, b.article_id, b.title, b.id, b.name, d.uid, 
       date_format(b.created, '%m/%d') as created, 
       round(b.count * 0.01 + b.recom * 3 + 10 * b.recom * 100 / ( b.count )
           + b.comments * 0.3 ) as score, 
       (timestampdiff(MINUTE, b.created, date_sub(now(), interval 3 day)) + abs(timestampdiff(MINUTE, b.created, date_sub(now(), interval 3 day)))) / (2 * 60 * 24) * 50 as expiry, 
       c.body 
from bw_xboard_board as a, bw_xboard_stat_article as b, bw_xboard_body as c, bw_xauth_passwd as d
where d.id like b.id && a.board_id=b.board_id && b.article_id=c.article_id
   && b.ki > 1 && b.created > date_sub(now(), interval 5 day)
order by (score - expiry) desc);
#my $hot = qq(select a.title as board_title, b.board_id, b.article_id, b.title, b.id, b.name, d.uid, date_format(b.created, '%m/%d') as created, round(b.count * 0.01 + b.recom * 3 + 10 * b.recom * 100 / ( b.count ) + b.comments * 0.3 ) as score from bw_xboard_board as a, bw_xboard_stat_article as b, bw_xboard_body as c, bw_xauth_passwd as d where d.id like b.id && a.board_id=b.board_id && b.article_id=c.article_id && b.ki > 1 order by score desc limit 10);

# in principle, this should be changed to row ref or anything that preserves the order
my $hot_stat = $dbh->selectall_hashref($hot, 'article_id');

my @hot_stat;

# because of the hash nature, we are redoing the sorting! this should not be so.
foreach my $i (sort { ($$hot_stat{$b}->{score} - $$hot_stat{$b}->{expiry})  <=> ($$hot_stat{$a}->{score} - $$hot_stat{$b}->{expiry}) } keys %$hot_stat) {
    if ($$hot_stat{$i}->{score} - $$hot_stat{$i}->{expiry} * 100 > 
    my $body = $$hot_stat{$i}->{body};
    $body =~ s/<\S+.*>//sg;
    $body =~ s/([-=])+//g;
    $body =~ s/(\.\.)+//g;
    $body =~ s/[http|mms]\S+//g;
    my @body = split(/\s+/, $body);
    my $last = $#body < 15 ? $#body : 15;
    $$hot_stat{$i}->{body} = join(" ", @body[0..$last]) . "... [more]";
    push @hot_stat, $$hot_stat{$i};
}

$t->param(hot_stat=>\@hot_stat);

my $board = qq(select a.title, b.board_id from bw_xboard_board as a, bw_xboard_stat_board as b where a.board_id=b.board_id and b.board_id != 688 order by round(b.articles * 3 + b.counts * 0.1 + b.recoms * 3 + (b.counts + b.comments * 5 + b.recoms * 50) / b.articles) desc limit 3);

my $board_stat = $dbh->selectall_arrayref($board);
my @board_stat = map { { title=>$$_[0], board_id=>$$_[1] } } @$board_stat;
$t->param(board_stat=>\@board_stat);


my $user = qq(select id, name from bw_xboard_stat_user order by round(articles * 5 + recoms * 5 + counts * 0.1 + (counts * 1+ comments* 5 + recoms * 50) / articles) desc limit 3);

my $user_stat = $dbh->selectall_arrayref($user);
my @user_stat = map { { id=>$$_[0], name=>$$_[1] } } @$user_stat;
$t->param(user_stat=>\@user_stat);

my $gbook = $dbh->selectall_arrayref(qq(select a.ki, b.name, b.id, b.uid, count(distinct c.guest_uid) as count, count(*) as articles from bw_user_ki as a, bw_xauth_passwd as b, bw_user_gbook as c where a.uid=b.uid && b.uid=c.uid && a.ki > 0 && c.created > DATE_SUB(NOW(), INTERVAL 24 HOUR) group by b.id order by count desc, articles desc, a.ki, b.name limit 3));
my @gbook = map { { name=>$$_[1], id=>$$_[2], uid=>$$_[3] } } @$gbook;
$t->param(gbook_stat=>\@gbook);

my $nb = qq(select title, board_id, date_format(created, '%m/%d') as created, id, name from bw_xboard_board where created > date_sub(now(), interval 7 day) && articles > 0);
my $new_board = $dbh->selectall_hashref($nb, 'board_id');

my @new_board = map { $$new_board{$_} } sort { $$new_board{$b}->{board_id} <=> $$new_board{$a}->{board_id} } keys %$new_board;
$t->param(new_board=>\@new_board);


my $articles = $dbh->selectrow_array('select format(count(*), 0) from bw_xboard_header;');

my $comments = $dbh->selectrow_array('select format(count(*), 0) from bw_xboard_comment;');
$t->param(articles=>$articles);
$t->param(comments=>$comments);

my $lastdayfix = ((localtime)[4] + 1 . "/" . (localtime)[3]) eq "12/31" ? "desc" : "";

my $birth = qq(select a.ki, b.id, b.name, date_format(c.birth, "%m/%d") as birth from bw_user_ki as a, bw_xauth_passwd as b, bw_user_basic c where a.uid=b.uid && b.uid=c.uid && ((date_format(c.birth, '%m-%d') = date_format(now(), '%m-%d')) || (date_format(c.birth, '%m-%d') = date_format(now() + interval 1 day, '%m-%d'))) && a.ki > 0 && c.death='0000-00-00' order by birth $lastdayfix, a.ki, b.name);
my $birthday = $dbh->selectall_arrayref($birth);
my @birthday = map {
  my $class = "opt hidden"; $class = "" if abs($user_ki - $$_[0]) < 6;
  { ki=>$$_[0], id=>$$_[1], name=>$$_[2], birth=>$$_[3], class=>$class }
} @$birthday;
$t->param(birthday=>\@birthday);
$t->param(date=> (localtime)[4] + 1 . "/" . (localtime)[3]);

my $anniversary = qq(select a.ki, b.id, b.name, YEAR(now()) - YEAR(c.wedding) as year from bw_user_ki as a, bw_xauth_passwd as b, bw_user_basic as c where a.uid=b.uid && b.uid=c.uid && DATE_FORMAT(c.wedding, '%m-%d')=DATE_FORMAT(now(), '%m-%d') && c.wedding < now() order by a.ki, b.name);
my $anni = $dbh->selectall_arrayref($anniversary);
my @anniversary = map { { ki=>$$_[0], id=>$$_[1], name=>$$_[2], year=>$$_[3] } } @$anni;
$t->param(anniversary=>\@anniversary);

my $modified = qq(select a.ki, b.id, b.name from bw_user_ki as a, bw_xauth_passwd as b, bw_user_basic as c where a.uid=b.uid && b.uid=c.uid order by c.modified desc, a.ki, b.name limit 5);
my $mod = $dbh->selectall_arrayref($modified);
my @modified = map { { ki=>$$_[0], id=>$$_[1], name=>$$_[2] } } @$mod;
$t->param(modified=>\@modified);

my $recent = q(select a.title as board_title, a.board_id, b.article_id, b.title, b.name, b.id, @rownum:=@rownum+1 as rownum from bw_xboard_board as a, bw_xboard_header as b, (select @rownum:=0) as c where a.board_id=b.board_id && a.gid!=18 && a.is_anonboard=0 && a.allow_recom=1 order by b.article_id desc limit 40);
my $rec = $dbh->selectall_hashref($recent, 'article_id');
my @recent;
foreach my $i (sort { $b <=> $a } keys %$rec ) {
    $$rec{$i}->{title} = $q->escapeHTML($$rec{$i}->{title});
    $$rec{$i}->{class} = "opt hidden" if $$rec{$i}->{rownum} > 5;
    push @recent, $$rec{$i};
}
$t->param(recent=>\@recent);

my $support = $dbh->selectrow_array('select format(sum(amount), 0) from bw_user_support');
$t->param(support=>$support);

my $users = $dbh->selectrow_array('select count(*) from bw_xauth_passwd');
$t->param(users=>$users);

$dbh->disconnect;
################################################################################


################################################################################
my $t1 = new Benchmark;
my $runtime = timestr(timediff($t1, $t0));
$t->param(runtime=>$runtime);

print $ui->output;
1;
