#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::Main::UI;
use CGI qw(escape escapeHTML);

my $ui = new Bawi::Main::UI(-template=>'search2.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my ($type, $keyword, $page) = map { $ui->cparam($_) || '' } qw(type keyword page);
$type = 'article' unless ($type);
$page = '1' unless ($page);

if ($type && $type =~ /article|people|board/ && $keyword) {

    $ui->tparam(page=>$page);
    $ui->tparam(keyword=>$ui->cgi->escapeHTML($keyword));
    $ui->tparam($type=>1);
    if ($type eq 'article') {
        $ui->tparam(result_article=>&search_article($keyword, $ui, $page)); 
    } elsif ($type eq 'people') {
        $ui->tparam(result_people=>$user->search_people($keyword));
        $ui->tparam(has_career=>$user->has_career($auth->uid));
    } elsif ($type eq 'board') {
        $ui->tparam(result_board=>&search_board($keyword, $ui));
    }
} else {
    $ui->tparam(article=>1);
}

print $ui->output;

sub get_tot_page {
    my ($tot_article, $article_per_page) = @_;
    return 1 unless ($tot_article && $article_per_page);

    my $tot_page = int( $tot_article / $article_per_page );
    ++$tot_page if ($tot_article % $article_per_page);
    $tot_page = 1 if ($tot_page < 1);
    return $tot_page;
}

sub search_board {
    my $keyword = shift;
    my $ui = shift;
    $keyword = escapeHTML($keyword);
    my $sql = qq(select a.board_id, a.title, a.gid, a.id, a.name, b.ki, 
                        c.title as group_title
                 from bw_xboard_board as a, bw_user_ki as b, bw_group as c
                 where a.uid=b.uid && a.gid=c.gid && (a.title like ? || a.name like ? || a.id like ?));
    my $rv = $ui->dbh->selectall_hashref($sql, 'board_id', undef, ("\%$keyword\%") x 3);
    my @rv = map { $$rv{$_} }
                 sort { $$rv{$a}->{gid} <=> $$rv{$b}->{gid} ||
                        $$rv{$a}->{title} cmp $$rv{$b}->{title}
                      } keys %$rv;
    return \@rv;
}

sub search_article {
    my $keyword = shift;
    my $ui = shift;
    my $page = shift;
    $keyword = escapeHTML($keyword);

    #my $sql = qq(select count(*)
    #             from bw_xboard_body as a, bw_xboard_header as b
    #             where a.article_id = b.article_id && (match (a.body) against (?) || match (b.title) against (?)));
    #$tot_article = $ui->dhb->selectrow_array($sql, 'article_id', undef, ("\%$keyword\%") x 2);
    #$tot_page = &get_tot_page($tot_article, $article_per_page);

    my $sql = qq(select a.article_id, a.board_id, concat(replace(left(a.body,50), '<', '&lt;'), '......') as body,
                        b.title, b.id, b.name, b.created,
                        c.title as board_title
                 from bw_xboard_body as a, bw_xboard_header as b, bw_xboard_board as c
                 where a.article_id = b.article_id && a.board_id = c.board_id && (match (a.body) against (?) || match (b.title) against (?))
                 order by a.article_id desc limit ?, 10);
    my $rv = $ui->dbh->selectall_hashref($sql, 'article_id', undef, ($keyword) x 2, ($page-1) * 10);
    my @rv = map { $$rv{$_} }
                sort { $$rv{$b}->{article_id} <=> $$rv{$a}->{article_id}
                     } keys %$rv;
    return \@rv;
}

1;
