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

my ($uid) = ($auth->{uid});
my ($bid) = map { $q->param($_) || undef } qw( bid );

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $skin = $xb->skin || '';

$ui->init(-template=>'opml.tmpl', -skin=>$skin);
my $t = $ui->template;

################################################################################
## main
################################################################################

my $bm = $xb->get_bookmarkset(-uid=>$uid);

my @bm;
foreach my $b ( @$bm ){
    $b->{title} =~ s/>/&gt;/g;
    push( @bm, {board_id => $b->{board_id}, board_title => $b->{title} });
}

$t->param(outline=>\@bm);


################################################################################

print $q->header(-type=>'text/xml', -charset=>'utf-8');
print $t->output;
1;
