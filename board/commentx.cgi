#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use Bawi::Board::Group;

my $ui = new Bawi::Board::UI(-template=>'_comment.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($ui->cfg->AllowAnonAccess == 1 || $auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $q = $ui->cgi;

my ($action, $bid, $aid, $p, $img) = map {$q->param($_) || ''} qw(action bid aid p img);

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh) 
    if ($bid);

my $grp = new Bawi::Board::Group(-gid=>$xb->gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my ($uid, $id, $name);
if ($auth->auth) {
    $uid = $auth->uid;
    if ($xb->is_anonboard) {
        $id = '*';
        $name = '*';
    } else {
        $id = $auth->id;
        $name = $auth->name;
    }
} elsif ($q->param('name') ) {
    ($uid, $id, $name) = (0, 'guest', $q->param('name') );
} else {
    ($uid, $id, $name) = (0, 'guest', 'guest');
}

my $allow_comment = $grp->authz(-uid=>$uid, 
                                -ouid=>$xb->uid,
                                -gperm=>$xb->g_comment,
                                -mperm=>$xb->m_comment,
                                -aperm=>$xb->a_comment);
if ($xb->board_id && $allow_comment) {
    my $method = $q->request_method || '';
    if ($action eq 'add' && $method eq 'POST') {
        if (&check_param($q, qw(bid body aid p)) == 0) {
            #my $body = $ui->substrk( $q->param('body'), 200);
            my $body = $q->param('body');
            my %data = (
                -board_id=>$bid,
                -article_id=>$aid,
                -body=>$body,
                -uid=>$uid,
                -id=>$id,
                -name=>$name,
            );
            my $rv = $xb->add_comment(%data);
        }
    } elsif ($action eq 'delete') {
        if (&check_param($q, qw(bid aid cid p)) == 0) {
            my $rv = $xb->get_comment(-comment_id=>$q->param('cid'));
            my $del = $xb->del_comment(-comment_id=>$q->param('cid'), -article_id=>$q->param('aid'), -board_id=>$q->param('bid') )
                if (${$rv}{uid} == $uid);
        }
    } elsif ($action eq 'update') {
    }
}

if ($action eq 'save') {

} elsif ($action eq 'update') {
    print $ui->output(-type=>'text/xml');
}

1;
