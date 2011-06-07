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

my ($bid, $p, $aid, $del) = map { $q->param($_) || undef } qw( bid p aid del );


my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $skin = $xb->skin || '';

$ui->init(-template=>'delete.tmpl', -skin=>$skin);
$ui->tparam(HTMLTitle=>$xb->title." (".$xb->id.")");
my $t = $ui->template;

my %form = $ui->form(qw(bid aid p));

if ($bid && $bid =~ /^\d+$/ && $aid && $aid =~ /^\d+$/) {
    $p = $xb->tot_page unless ($p && $p =~ /^\d+$/);
    $t->param(board_title=>$xb->title);
    my $article = $xb->get_article(-article_id=>$aid, -page=>$p);
    if ($article) {
        $t->param(ano=>$article->{article_no});
        $t->param(title=>$article->{title});
        $t->param(name=>$article->{name});
        $t->param(id=>$article->{id});
        if ($del && $del eq 'ok' && $article->{uid} == $auth->uid) {
            my $rv = $xb->del_article(-board_id=>$bid, -article_id=>$aid);
            print $q->redirect("read.cgi?bid=$bid&p=$p");
            exit (1);
        }
    }
}

print $ui->output;
1;
