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

# Action endpoint: no page shell renders here (every exit is a redirect
# or XML), but bounce anonymous requests against members-only boards
# before any processing, in parity with read.cgi's shell guard (PR #34).
# Guests proceed when the board grants anonymous read or anonymous
# comment (authz(-aperm=>a_comment) below still gates the actual action).
# is_anonboard masks author identity, it never grants access. !$xb: a
# bid-less request has no board to leak; it falls through to the
# pre-existing error path at the Group constructor below.
unless (!$xb || $auth->auth || ($xb->a_read || 0) == 1 || ($xb->a_comment || 0) == 1) {
    # A POST's return URL must not carry the request params: cgiurl
    # rebuilds the query from them, comment body included -- member text
    # in the Location header and access logs, and a long body 414s the
    # login redirect (the post-login GET replay could not re-add the
    # comment anyway). Point a bounced POST back at the article.
    my $back = $ui->cgiurl;
    if (($q->request_method || '') eq 'POST') {
        ($back = $q->url(-path_info=>1)) =~ s{commentx\.cgi\z}{read.cgi};
        $back .= '?bid=' . $q->escape($bid) . ';aid=' . $q->escape($aid);
    }
    print $auth->login_page($back);
    exit (1);
}

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
            # $auth->auth: guests set $name from the form -- never let a
            # request-supplied identity author a note.
            if ($rv && $auth->auth && !$xb->is_anonboard) {
                require Bawi::Main::Note;
                my $proto = $ENV{HTTPS} ? 'https' : 'http';
                my $dir = $ENV{SCRIPT_NAME} || '';
                $dir =~ s#[^/]*$##;
                my $url = "$proto://$ENV{HTTP_HOST}${dir}" . Bawi::Main::Note::mention_note_tail($bid, $aid, $rv);
                my $note = new Bawi::Main::Note(-dbh=>$ui->dbh);
                $note->notify_mentions($body, $id, $name, $url);
            }
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

# mirrors comment.cgi's check_param -- this sibling never had it, so the
# add/delete actions above died with "Undefined subroutine" since their
# introduction (each ModPerl::Registry script is its own package; nothing
# imports it). Exposed by smoke tier 4's commentx round-trip.
sub check_param {
    my ($q, @list) = @_;
    my $check = 0;
    foreach my $i (@list) {
        ++$check unless (defined $q->param($i) && $q->param($i) ne '');
    }
    return $check;
}

1;
