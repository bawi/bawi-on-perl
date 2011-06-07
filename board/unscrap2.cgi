#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;

my $ui = new Bawi::Board::UI(-template=>'tagArticle.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $q = $ui->cgi;
my $session_key = $q->param('s') || '';

my ($error, $msg, $type, $article_id) = (0, '', 'unscrap', 0);
if ($session_key && $auth->auth(-session_key=>$session_key)) {
    my $uid = $auth->uid;
    my ($bid, $aid) = map { $q->param($_) || undef } qw( bid aid);

    my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);

    if ($aid && $uid) {
        my $article_uid = $xb->get_article_uid(-article_id=>$aid);
        my $rv = $xb->get_scrap(-article_id=>$aid, -uid=>$uid);
        if ($rv) {
            my $rv2 = $xb->delete_scrap(-article_id=>$aid, -uid=>$uid);
            if ($rv2) {
                $msg = "Unscrapped.";
                $article_id = $aid;
            }
#            $error = 1;
#            $msg = "Already scrapped.";
#        } elsif ($article_uid ne $uid && $xb->allow_scrap && ! $xb->is_anonboard) {
         } else {
            $error = 1;
            $msg = "Not scrapped at all!";
         }
    }
} else {
    $error = 1;
    $msg = "Authentication failed.";
}

$ui->tparam(error=>$error, msg=>$msg, type=>$type, aid=>$article_id);
print $ui->output(-type=>'text/xml');

1;
