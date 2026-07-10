#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::Main::UI;
use CGI qw(escape escapeHTML);

my $ui = new Bawi::Main::UI(-template=>'search.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my ($type, $keyword) = map { $ui->cparam($_) || '' } qw(type keyword);
$type = 'article' unless ($type);

if ($type && $type =~ /article|people|board/ && $keyword) {

    $ui->tparam(keyword=>$ui->cgi->escapeHTML($keyword));
    $ui->tparam($type=>1);
    if ($type eq 'article') {
        my $escaped = escape($keyword);
        #print $ui->cgi->redirect("/search/board/index.cgi?q=$escaped");
        exit(1);
    } elsif ($type eq 'people') {
        $ui->tparam(result_people=>$user->search_people($keyword));
        $ui->tparam(has_phone=>$user->has_phone($auth->uid));
        $ui->tparam(has_affiliation=>$user->has_affiliation($auth->uid));
        $ui->tparam(has_career=>$user->has_career($auth->uid));
    } elsif ($type eq 'board') {
        $ui->tparam(result_board=>&search_board($keyword, $ui));
    }
} else {
    $ui->tparam(article=>1);
}

print $ui->output;

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

1;
