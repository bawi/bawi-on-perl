#!/usr/bin/perl -w
use strict;
use lib '../lib';

use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::Group;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($ui->cfg->AllowAnonAccess == 1 || $auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $q = $ui->cgi;

################################################################################
## main
################################################################################
my ($bid, $aid, $resize, $img) = map { $q->param($_) || undef } qw( bid aid resize img);

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $skin = $xb->skin;

my ($uid, $id, $name);
if ($auth->auth and $xb->is_anonboard) {
    ($uid, $id, $name) = ($auth->uid, 'guest', 'guest');
} elsif ($auth->auth) {
    ($uid, $id, $name) = ($auth->uid, $auth->id, $auth->name);
} elsif ($q->param('name') ) {
    ($uid, $id, $name) = (0, 'guest', $q->param('name') );
} else {
    ($uid, $id, $name) = (0, 'guest', 'guest');
}

$ui->init(-template=>'write.tmpl', -skin=>$skin);
$ui->term(qw(T_BOARD T_WRITE T_TITLE T_BODY T_FILE T_POLL T_OPTION T_SAVE));

$ui->tparam(HTMLTitle=>$xb->title." (".$xb->id.")");
$ui->tparam(id=>$auth->id);
$ui->tparam(is_admin=>$auth->is_admin);
$ui->tparam(board_id=>$bid);
$ui->tparam(board_title=>$xb->title);
$ui->tparam(owner=>[{name=>$xb->name, id=>$xb->id}] );
$ui->tparam(img=>$img);
$ui->tparam(member=>1) if $auth->auth;

my $t = $ui->template;

my $allow_attach = $xb->allow_attach || 0;
my $AllowAttach = $ui->cfg->AllowAttach || 0;
if ($allow_attach && $AllowAttach) {
    $t->param(allow_attach=>1);
    $t->param(attach_limit=>$xb->attach_limit_bytes);
    $t->param(image_width=>$xb->image_width);
}

my $grp = new Bawi::Board::Group(-gid=>$xb->gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
$t->param(path=>$grp->get_path);
my $allow_read = $grp->authz(-uid   => $uid, 
                             -ouid  => $xb->uid,
                             -gperm => $xb->g_read,
                             -mperm => $xb->m_read,
                             -aperm => $xb->a_read);
$t->param(allow_read=>$allow_read);
my $allow_write = $grp->authz(-uid=>$uid, 
                              -ouid=>$xb->uid,
                              -gperm=>$xb->g_write,
                              -mperm=>$xb->m_write,
                              -aperm=>$xb->a_write);
$t->param(allow_write=>$allow_write);

if ($allow_write && $bid) {
    my $p = $xb->tot_page; 
    $t->param(bid=>$bid);
    $t->param(p=>$p);

    my ($ftitle, $fbody, $poll) 
        = map { $q->param($_) || '' } qw( title body poll);
    $ftitle =~ s/^\s+//g;
    $ftitle =~ s/\s+$//g;
    my $signature = '';
    $signature = $xb->get_sig(-uid=>$uid) unless ($xb->is_anonboard);

    my ($article_id, $pno, $tno);
    if ($aid) { # write reply to $aid 
        $t->param(aid=>$aid);
        my $article = $xb->get_article(-board_id=>$bid, 
                                       -article_id=>$aid, 
                                       -page=>$p );
        ($pno, $tno) = @{$article}{'article_no', 'thread_no'};

        # read original title & body & set these for default form values
        my ($original_name, $title, $body) = @{$article}{'name', 'title', 'body'};
        $original_name = '' if ($xb->is_anonboard);
        $body = ""; # TODO fix for expiration check
        $body =~ s/\n/\n> /g;
        $body =~ s/&/&amp;/g;
        $body = "$original_name 님께서 쓰시길,\n> " . $body . "\n";
        $body .= "\n\n--\n" . $signature if $signature;
        $title = "Re: $title" unless ($title =~ /^Re: /);
        $title = substr($title, 0, 64) if (length $title > 64);
        #$t->param(title=> $q->escapeHTML($title));
        #$t->param(body => $q->escapeHTML($body ));
        $t->param(title=>$title, body=>$body);

    } else { # write new article
        # board_id, title, body: from form
        my $body = "\n\n\n--\n" . $signature if $signature;
        $t->param(body=> $q->escapeHTML($body));
    }

    # add new article if title & body are passed from the form
    if ($ftitle && $fbody) {
        $article_id = $xb->add_article(-board_id    =>$bid,
                                       -parent_no   =>$pno,
                                       -thread_no   =>$tno,
                                       -title       =>$ftitle,
                                       -body        =>$fbody,
                                       -uid         =>$uid,
                                       -id          =>$id,
                                       -name        =>$name);
    } elsif ($ftitle) {
        $t->param(title=> $q->escapeHTML($ftitle));
        $ui->msg(qq(Body is missing.));
    } elsif ($fbody) {
        $t->param(body=> $q->escapeHTML($fbody));
        $ui->msg(qq(Title is missing.));
    }
  
    if ($article_id) { 
        my $attach = $xb->upload_attach(-query=>$q);
        if ($attach) {
            foreach my $i (@$attach) {
                if ($resize && $resize eq '1' && $$i{is_img} eq 'y') { 
                    $$i{file} = $xb->img_resize(-image=>$$i{file}, 
                                                 -size=>$xb->image_width);
                    $$i{filesize} = length($$i{file});
                }
                $xb->add_attach(-board_id       => $bid,
                                -article_id     => $article_id,
                                -file           => $$i{file},
                                -filename       => $$i{filename},
                                -filesize       => $$i{filesize},
                                -content_type   => $$i{content_type},
                                -is_img         => $$i{is_img});
            }
        }
        if ($poll) {
            my $rv = $xb->add_pollset(-query=>$q, -article_id=>$article_id); 
        }
        print $q->redirect("read.cgi?bid=$bid&aid=$article_id&autosave=1");
        exit (1);
    }
} else {
    $ui->msg(qq(You don't have permission to write.));
}

if (param_check($q) == 0) {
    my ($bid, $ano, $tno, $title, $body) 
        = map { $q->param($_) } qw( bid ano tno title body); 
    my $b = new Bawi::Board(-board_id=>$bid);
    my $p = $q->param('p') || $b->{tot_page};
    print $q->redirect("read.cgi?bid=$bid&p=$p");
    exit 1;
}
################################################################################

print $ui->output;

sub param_check {
    my $q = shift;

    my $error = 0;
    foreach my $i ( qw( bid ano tno ) ) {
        my $value = $q->param($i) if $q->param($i);
        ++$error unless ($value && $value =~ /^\d+$/);
    }
    foreach my $i ( qw( title body ) ) {
        my $value = $q->param($i) if $q->param($i);
        ++$error unless ($value);
    }
    return $error;
}

1;
