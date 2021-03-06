#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;
use Encode qw/encode decode/;

my $ui = new Bawi::Board::UI(-template=>'update.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

my ($error, $msg, $xid) = (0, '', 0);
if ($auth->auth) {
    # id: c12345/t12345. c: comment, t: title
    my ($id, $text) = map { $ui->cparam($_) || '' } qw(id text);
    print STDERR "is utf8: ", utf8::is_utf8($text) ? 1: 0, "\n";
    print STDERR "text utf8: $text\n";
    $text = encode("utf-8", $text); # convert utf8 to euc-kr
    print STDERR "text utf-8: $text\n";
    my $obj = '';
    if ($id =~ /([ct])(\d+)/) {
        ($obj, $id) = ($1, $2);
    }
    my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
    if ($obj eq 'c') {
        #$text = $ui->substrk($text, 200);
        my $rv = $xb->edit_comment(-comment_id=>$id, -body=>$text, -uid=>$auth->uid)
            if ($text);
        if ($rv) {
            my $comment = $xb->get_comment(-comment_id=>$id);
            $msg = decode("utf-8", $comment->{body});
            print STDERR "msg: $msg\n";
            $xid = "c" . $id;
        } else {
            ++$error;
            $msg = 'Comment is not updated.';
        }
    } elsif ($obj eq 't') {
        $text = $ui->substrk2($text, 64);
       my $rv = $xb->edit_article_title(-article_id=>$id, -title=>$text, -uid=>$auth->uid);
    }
} else {
    $error = 1;
    $msg = "Authentication failed.";
}
$ui->tparam(error=>$error);
$ui->tparam(msg=>$msg);
$ui->tparam(id=>$xid);
$ui->tparam(encoding=>$ui->cfg->CharSet);
print $ui->output(-type=>'text/xml');

1;
