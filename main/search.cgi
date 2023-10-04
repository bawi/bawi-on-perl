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
        $ui->tparam(result_people=>&search_people($keyword, $ui));
        $ui->tparam(has_phone=>$user->has_phone($auth->uid));
        $ui->tparam(has_affiliation=>$user->has_affiliation($auth->uid));
    } elsif ($type eq 'board') {
        $ui->tparam(result_board=>&search_board($keyword, $ui));
    }
} else {
    $ui->tparam(article=>1);
}

print $ui->output;

sub search_people {
    my $keyword = shift;
    my $ui = shift;
    my $sql = qq(select a.id, a.name, b.ki, c.affiliation, c.mobile_tel, c.office_address
                 from bw_xauth_passwd as a, bw_user_ki as b, bw_user_basic as c
                 where a.uid=b.uid && a.uid=c.uid && 
                       (a.id like ? || a.name like ? || c.affiliation like ? ||
                        c.home_address like ? || c.office_address like ? || c.temp_address like ? ||
                        c.mobile_tel like ? || c.home_tel like ? ||
                        c.office_tel like ? || c.temp_tel like ?));
    my $rv = $ui->dbh->selectall_hashref($sql, 'id', undef, ("\%$keyword\%") x 10);
    my @rv = map { $$rv{$_} }
                 sort { $$rv{$a}->{ki} <=> $$rv{$b}->{ki} ||
                        $$rv{$a}->{name} cmp $$rv{$b}->{name} ||
                        $$rv{$a}->{id} cmp $$rv{$b}->{id} 
                      } keys %$rv;
    return \@rv;
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

1;
