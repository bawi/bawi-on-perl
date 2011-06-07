#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::Group;
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
my ($bid, $p, $aid, $a, $resize, $img, $poll) 
    = map { $q->param($_) || undef } qw( bid p aid a resize img poll );

my $xb = new Bawi::Board(-board_id=>$bid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $skin = $xb->skin || '';

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

$ui->init(-template=>'edit.tmpl', -skin=>$skin);
$ui->term(qw(T_BOARD T_WRITE T_EDIT T_TITLE T_BODY T_FILE T_POLL T_OPTION T_SAVE));

my $t = $ui->template;
$ui->tparam(HTMLTitle=>$xb->title." (".$xb->id.")");
$ui->tparam(id=>$auth->id);
$ui->tparam(is_admin=>$auth->is_admin);
$ui->tparam(board_id=>$bid);
$ui->tparam(board_title=>$xb->title);
$ui->tparam(owner=>[{name=>$xb->name, id=>$xb->id}] );
$ui->tparam(img=>$img);
$ui->tparam(member=>1);

my $allow_attach = $xb->allow_attach || 0;
my $AllowAttach = $ui->cfg->AllowAttach || 0;
if ($allow_attach && $AllowAttach) {
    $t->param(allow_attach=>1);
    $t->param(attach_limit=>$xb->attach_limit_bytes);
    $t->param(image_width=>$xb->image_width);
}

my $grp = new Bawi::Board::Group(-gid=>$xb->gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $allow_write = $grp->authz(-uid      => $uid, 
                              -ouid     => $xb->uid,
                              -gperm    => $xb->g_write,
                              -mperm    => $xb->m_write,
                              -aperm    => $xb->a_write);
$t->param(allow_write=>$allow_write);

if ($allow_write && $bid && $bid =~ /^\d+$/ && $aid && $aid =~ /^\d+$/) {
    $p = $xb->tot_page unless ($p && $p =~ /^\d+$/ && $p <= $xb->tot_page);
    $t->param(bid=>$bid);
    $t->param(p=>$p);
    $t->param(aid=>$aid);
    $t->param(board_title=>$xb->title);
    $t->param(img=>$img);
    $t->param(article_id=>$aid);

    my $article = $xb->get_article(-article_id=>$aid, -page=>$p);
    if (exists $article->{uid} && $article->{uid} == $uid) {
        my $title = $article->{title};
        my $body  = $article->{body};
        $t->param(title=> $q->escapeHTML($title));
        $t->param(body => $q->escapeHTML($body));
        $t->param(attach=>$xb->get_attachset(-article_id=>$aid));
        if ($q->request_method() && $q->request_method eq 'POST') {
            my $attach = $xb->upload_attach(-query=>$q);
            if ($attach) {
                warn("upload_attach() returned empty array value: error on saving file(s)")
                    if scalar @{$attach} == 0;
                foreach my $i (@$attach) {
                    if ($resize && $resize eq '1' && $$i{is_img} eq 'y') {
                        $$i{file} = $xb->img_resize(-image=>$$i{file},
                                                    -size=>$xb->image_width);
                        $$i{filesize} = length($$i{file});
                    }
                    $xb->add_attach(-board_id     => $bid,
                                    -article_id   => $aid,
                                    -file         => $$i{file},
                                    -filename     => $$i{filename},
                                    -filesize     => $$i{filesize},
                                    -content_type => $$i{content_type},
                                    -is_img       => $$i{is_img});
                }
            }
            if ($poll) {
                my $rv = $xb->add_pollset(-query=>$q, -article_id=>$aid); 
            }
            my ($ftitle, $fbody) = map { $q->param($_) || '' } qw( title body );
            if ($ftitle ne '' && $fbody ne '') {
                #$ftitle = $ui->substrk2($ftitle, 50); ### NOTE 
                my $rv = $xb->edit_article(-article_id=>$aid, 
                                           -title=>$ftitle, 
                                           -body=>$fbody);
                print $q->redirect("read.cgi?bid=$bid&aid=$aid&p=$p");
                exit (1);
            } else {
                $t->param(title=> $q->escapeHTML($title));
                $t->param(body => $q->escapeHTML($body));
                #$t->param(title=>$title, body=>$body);
                $ui->msg(qq(Title or body is missing.));
            }
        } else {
            # you may change the layout so that it looks finer
            $t->param(pollset=>$xb->get_pollset(-article_id=>$aid,
                                                -uid=>$uid,
                                                -page=>$p)) if ($$article{has_poll});
        }
    }
} else {
    $ui->msg(qq(You don't have write-permission.));
}

################################################################################

print $ui->output;
1;
