#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use Bawi::Board::Group;

my $ui = new Bawi::Board::UI;
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
my $redirect_position = "";
if ($xb->board_id && $allow_comment) {
    my $method = $q->request_method || '';
    if ($action eq 'add' && $method eq 'POST') {
        if (&check_param($q, qw(bid aid body)) == 0) {
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
            $redirect_position = "#c$rv" if $rv;
        }
    } elsif ($action eq 'delete') {
        if (&check_param($q, qw(bid aid cid)) == 0) {
            my $rv = $xb->get_comment(-comment_id=>$q->param('cid'));
            my $del = $xb->del_comment(-comment_id=>$q->param('cid'), -article_id=>$q->param('aid'), -board_id=>$q->param('bid') )
                if (${$rv}{uid} == $uid);
        }
    }
}

if ($q->param("redirect") and $q->param("redirect") eq 'mycomment') {
    print $ui->cgi->redirect("mycomment.cgi?p=$p".$redirect_position);
} else {
    print $ui->cgi->redirect("read.cgi?bid=$bid&aid=$aid&p=$p&img=$img".$redirect_position);
}

sub check_param {
    my ($q, @list) = @_;
    my $check = 0;
    foreach my $i (@list) {
        ++$check unless (defined $q->param($i) && $q->param($i) ne '');
    }
    return $check;
}

1;
