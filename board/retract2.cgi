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

my ($error, $msg, $type, $article_id) = (0, '', 'retract', 0);
if ($session_key && $auth->auth(-session_key=>$session_key)) {
    my ($uid, $id, $name) = ($auth->uid, $auth->id, $auth->name);
    my ($bid, $aid) = map { $q->param($_) || undef } qw( bid aid );

    my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);

    if ($aid && $uid) {
        my $article_uid = $xb->get_article_uid(-article_id=>$aid);
        my $rv = $xb->get_recommender(-article_id=>$aid, -uid=>$uid);
        if ($rv) {
            my $rv1 = $xb->retract_recommender(-article_id=>$aid, -uid=>$uid);
            if ($rv1) {
                $msg = "Retracted recommendation.";
                $article_id = $aid;
                my $rv2 = $xb->add_comment(-board_id   => $bid,
                                           -article_id => $aid,
                                           -body       => '추천 철회합니다.',
                                           -uid        => $uid,
                                           -id         => $id,
                                           -name       => $name)
                    if ($ui->cfg->AllowRecomComment);

            }
        } else {
            $error = 1;
            $msg = "Did not recommend yet.";
        }
    }
} else {
    $error = 1;
    $msg = "Authentication failed.";
}

$ui->tparam(error=>$error, msg=>$msg, type=>$type, aid=>$article_id);
print $ui->output(-type=>'text/xml');

1;
