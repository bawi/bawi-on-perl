#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI(-template=>'tagArticle.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $t = $ui->template;
my $session_key = $ui->cparam('s') || '';

my ($error, $msg, $type, $article_id) = (0, '', 'notice', '');
if ($session_key && $auth->auth(-session_key=>$session_key)) {
    my $bid = $ui->cparam('bid') || 0;
    my $page = $ui->cparam('p') || 0;
    my $aid = $ui->cparam('aid') || 0;

    if ($bid && $aid) {
        my $xb = new Bawi::Board(-cfg=>$ui->cfg,
                                  -board_id=>$bid,
                                  -dbh=>$ui->dbh);
        if ($xb && $xb->board_id) {
            my $is_notice = $xb->is_notice(-article_id=>$aid) || 0;
            my $uid = $auth->uid || 0;
            my $is_root = $uid == 1 ? 1 : 0;
            my $is_owner = ($uid == $xb->uid) || $is_root ? 1 : 0;
            if ($is_owner) {
                if ($is_notice) {
                    my $rv = $xb->del_notice(-article_id=>$aid);
                    if ($rv) {
                        $article_id = $aid;
                        $msg = "Deleted from notice list.";
                    }
                } else {
                    my $rv = $xb->add_notice(-article_id=>$aid);
                    if ($rv) {
                        $article_id = $aid;
                        $msg = "Added to notice list.";
                    }
                }
            } else {
                $error = 1;
                $msg = 'No permission.';
            }
        }
    }
} else {
    $error = 1;
    $msg = "Authentication failed.";
}

$ui->tparam(error=>$error, msg=>$msg, type=>$type, aid=>$article_id);
print $ui->output(-type=>'text/xml');

1;
