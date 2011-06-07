#!/usr/bin/perl -w
use Benchmark;
my $t0 = new Benchmark;
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::Group;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($ui->cfg->AllowAnonAccess == 1 or $auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $q = $ui->cgi;

################################################################################
## main
################################################################################
my ($uid, $id, $name, $session_key);
if ($auth->auth) {
    ($uid, $id, $name, $session_key) = ($auth->uid, $auth->id, $auth->name, $auth->session_key);
} else {
    ($uid, $id, $name, $session_key) = (0, 'guest', 'guest', '');
}

my ($bid, $aid, $la, $lc, $tno, $p, $a, $img, $keyword, $field) = 
    map { $q->param($_) || undef } qw( bid aid la lc tno p a img k f);

# keyword encoding for proper operation at IE.
my $enc_keyword = $q->escapeHTML($keyword) || '';
$enc_keyword =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;

$bid = 0 unless (defined $bid && $bid =~ /^\d+$/);
$p = 0 unless ($p && $p =~ /^\d+$/);

my $xb = new Bawi::Board(-board_id     => $bid, 
                          -img          => $img, 
                          -cfg          => $ui->cfg,
                          -keyword      => $keyword,
                          -field        => $field,
                          -page         => $p,
                          -dbh          => $ui->dbh,
                          -session_key  => $session_key);

my $skin = $xb->skin || 'default';
$ui->init(-template=>'read.tmpl', -skin=>$skin);
$ui->term(qw(T_BOOKMARK T_PREV T_NEXT T_NEWARTICLES T_IMGLIST T_ARTICLELIST T_WRITE T_THREAD T_REPLY T_EDIT T_DELETE T_TITLE T_NAME T_ID T_ADDBOOKMARK T_DELBOOKMARK T_SCRAP T_SCRAPPED T_READ T_RECOMMEND T_RECOMMENDED T_BOARDCFG T_ADDNOTICE T_DELETENOTICE T_NEWCOMMENTS T_COMMENT T_SAVE T_RESET));
my $t = $ui->template;
$t->param(HTMLTitle=>$xb->title." (".$xb->id.")");
$t->param(id=>$auth->id);
$t->param(is_admin=>$auth->is_admin);
$t->param(board_id=>$bid);
$t->param(board_title=>$xb->title);
$t->param(owner=>[{name=>$xb->name, id=>$xb->id}] );
$t->param(img=>$img);

my $dev = "";
$dev = $ENV{SERVER_NAME} if (exists $ENV{SERVER_NAME} and ($ENV{SERVER_NAME} ne "www.bawi.org"));
$t->param(dev=>$dev);

my $xb_uid = $xb->uid || -2;
my $is_root = $uid == 1 ? 1 : 0;
my $is_board_owner = ($uid == $xb_uid) || $is_root ? 1 : 0;
$t->param(is_board_owner=>$is_board_owner);

$p = $xb->tot_page unless ($p && $p =~ /^\d+$/ && $p <= $xb->tot_page);

my $grp = new Bawi::Board::Group(-gid=>$xb->gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
$t->param(path=>$grp->get_path);
my $allow_read = $grp->authz(-uid   => $uid, 
                             -ouid  => $xb_uid,
                             -gperm => $xb->g_read,
                             -mperm => $xb->m_read,
                             -aperm => $xb->a_read);
$t->param(allow_read=>$allow_read);

my $allow_write = $grp->authz(-uid   => $uid, 
                              -ouid  => $xb_uid,
                              -gperm => $xb->g_write,
                              -mperm => $xb->m_write,
                              -aperm => $xb->a_write);
$t->param(allow_write=>$allow_write);

my $allow_comment = $grp->authz(-uid   => $uid, 
                                -ouid  => $xb_uid,
                                -gperm => $xb->g_comment,
                                -mperm => $xb->m_comment,
                                -aperm => $xb->a_comment);

my $allow_recom = $xb->allow_recom;
my $allow_scrap = $xb->allow_scrap;
$t->param(allow_recom=>$allow_recom);
$t->param(allow_scrap=>$allow_scrap);
$t->param(a_read =>$xb->a_read);

my $article_set;
################################################################################
# article

my $article = $xb->get_article(-article_id=>$aid)
    if ($allow_read && $aid && $aid =~ /^\d+$/);

if ($article) {
    $$article{title} = $q->escapeHTML($$article{title}); 
    $$article{body} = $xb->format_article(-body=>$$article{body}, -article=>$article);
    $$article{comment} = $xb->get_commentset(-article_id=>$aid, -uid=>$uid)
        if ($$article{comments});
    $$article{attach} = $xb->get_attachset(-article_id=>$aid)
        if ($$article{has_attach});
    $$article{is_board_owner} = $is_board_owner if ($is_board_owner);
    $$article{is_notice} = $xb->is_notice(-article_id=>$aid);
    $$article{allow_comment} = $allow_comment;
    $$article{allow_write} = $allow_write;
    $$article{is_owner} = 1;
    unless ($$article{uid} == $uid) {
        $$article{is_owner} = 0;
        ++$$article{count};
        $xb->add_article_read_count(-article_id=>$aid);
    }
    $$article{pollset} = $xb->get_pollset(-article_id=>$aid, 
                                          -uid=>$uid,
                                          -page=>$p)
        if ($$article{has_poll});
    $article_set = [$article];
}

################################################################################
# thread

my $thread = $xb->get_thread(-thread_no=>$tno, -uid=>$uid)
    if ($allow_read && $tno && $tno =~ /^\d+$/);

if ($thread) {
    foreach my $i (@$thread) {
        $$i{title} = $q->escapeHTML($$i{title}); 
        $$i{body} = $xb->format_article(-body=>$$i{body});
        $$i{comment} = $xb->get_commentset(-article_id => $$i{article_id},
                                           -uid        => $uid)
            if ($$i{comments});
        $$i{attach} = $xb->get_attachset(-article_id=>$$i{article_id})
            if ($$i{has_attach});
        $$i{pollset} = $xb->get_pollset(-article_id=>$$i{article_id}, 
                                        -uid=>$uid,
                                        -page=>$p)
            if ($$i{has_poll});
        $$i{is_board_owner} = $is_board_owner if ($is_board_owner);
        $$i{is_notice} = $xb->is_notice(-article_id=>$$i{article_id});
        $$i{allow_comment} = $allow_comment;
        $$i{allow_write} = $allow_write;
        $$i{is_owner} = $$i{uid} == $uid ? 1 : 0;
    }
    $article_set = $thread;
    $t->param(total_thread=>$#{$thread} + 1);
}
################################################################################
# new articles

my $bm = $xb->get_bookmark(-board_id=>$bid, -uid=>$uid)
    if ($uid && $bid);

if ($allow_read and ( $la or $lc ) and $uid ) { 
    # la - last article no
    # lc - last comment no
    $xb->add_new_bookmark(-board_id=>$bid, -uid=>$uid) unless ($bm);
    if ($bm and ( $la or $lc )) { # new articles
        my $max_article_count = 15;
        my $na = $xb->get_new_articles(-article_no=>$la,
                                       -max_article_count=> $max_article_count);
        my $last_article = $na->[-1];
        $xb->set_article_bookmark(-article_no=>$last_article->{article_no}, 
                                  -board_id=>$bid, 
                                  -uid=>$uid);
        
        my %read_comment;
        my $max_comment_no = -1;
        if ($#{$na} > -1) {
            foreach my $i (@$na) {
                $$i{title} = $q->escapeHTML($$i{title}); 
                $$i{body} = $xb->format_article(-body=>$$i{body});
                $$i{is_owner} = $$i{uid} == $uid ? 1 : 0;
                $$i{is_board_owner} = $is_board_owner if ($is_board_owner);
                $$i{allow_comment} = $allow_comment;
                $$i{allow_write} = $allow_write;
                my $comment = $xb->get_commentset(-article_id=>$$i{article_id}, 
                                                  -uid=>$uid);
                $$i{comment} = $comment;
                foreach my $c (@$comment) {
                    ++$read_comment{ $$c{comment_id} };
                    $max_comment_no = $$c{comment_no} 
                        if( $max_comment_no < $$c{comment_no} );
                }
                $$i{attach} = $xb->get_attachset(-article_id=>$$i{article_id})
                    if ($$i{has_attach});
                $$i{pollset} = $xb->get_pollset(-article_id=>$$i{article_id}, 
                                                -uid=>$uid,
                                                -page=>$p)
                    if ($$i{has_poll});
            }
            $article_set = $na;
            $t->param(total_thread=>$#{$na} + 1);
        }
        my $new_comments = $xb->get_new_comments(-comment_no=>$lc,
                                                 -last_article_no=>$last_article->{article_no});
        my @new_comments;
        my %read_article;
        foreach my $c (@$new_comments) {
            $max_comment_no = $$c{comment_no} 
                if( $max_comment_no < ($$c{comment_no} || -1));

            $$c{title} = $q->escapeHTML($$c{title});
            $$c{is_owner} = $$c{uid} == $uid ? 1 : 0;
            $$c{allow_comment} = $allow_comment;
            unless ( $read_comment{ $$c{comment_id} } ) {
                if ($read_article{ $$c{article_no} }) {
                    delete $$c{article_no};
                    delete $$c{title};
                    delete $$c{artcl_name};
                    delete $$c{artcl_id};
                }
                ++$read_article{ $$c{article_no} }  if $$c{article_no};
                push @new_comments, $c;
            }
        }
        if( $max_comment_no < 0 ) { 
            $max_comment_no = $xb->max_comment_no; 
        }
        $xb->set_comment_bookmark(-board_id=>$bid, 
                                  -uid=>$uid, 
                                  -last_comment_no=>$max_comment_no );
        my $new_commentset = \@new_comments;
        $new_commentset = $xb->format_anon_list(-list=>$new_commentset)
            if ($xb->is_anonboard);
        $t->param(new_comments=> $new_commentset);
        $t->param(total_newcomments=>$#new_comments + 1);
    } elsif ($bm && $la eq 'rb') { # reset bookmark
        $xb->set_bookmark(-board_id=>$bid, -uid=>$uid);
    } elsif ($bm && $la eq 'db') { # delete bookmark
        $xb->del_bookmark(-board_id=>$bid, -uid=>$uid);
    }
} elsif ($allow_read && $a && $uid ) { 
    $xb->add_new_bookmark(-board_id=>$bid, -uid=>$uid) unless ($bm);
    if ($bm && $a eq 'na') { # new articles
        # n 개씩 끊어읽기. added by JikhanJung 20031128
        my $max_article_count = 15;
        my $na = $xb->get_new_articles(-article_no=>$bm->{article_no},
                                       -max_article_count=> $max_article_count);
        my $last_article = $na->[-1];
        $xb->set_article_bookmark(-article_no=>$last_article->{article_no}, 
                                  -board_id=>$bid, 
                                  -uid=>$uid);
        
        my %read_comment;
        my $max_comment_no = -1;
        if ($#{$na} > -1) {
            foreach my $i (@$na) {
                $$i{title} = $q->escapeHTML($$i{title}); 
                $$i{body} = $xb->format_article(-body=>$$i{body});
                $$i{is_owner} = $$i{uid} == $uid ? 1 : 0;
                $$i{is_board_owner} = $is_board_owner if ($is_board_owner);
                $$i{allow_comment} = $allow_comment;
                $$i{allow_write} = $allow_write;
                my $comment = $xb->get_commentset(-article_id=>$$i{article_id}, 
                                                  -uid=>$uid);
                $$i{comment} = $comment;
                foreach my $c (@$comment) {
                    ++$read_comment{ $$c{comment_id} };
                    $max_comment_no = $$c{comment_no} 
                        if( $max_comment_no < $$c{comment_no} );
                }
                $$i{attach} = $xb->get_attachset(-article_id=>$$i{article_id})
                    if ($$i{has_attach});
                $$i{pollset} = $xb->get_pollset(-article_id=>$$i{article_id}, 
                                                -uid=>$uid,
                                                -page=>$p)
                    if ($$i{has_poll});
            }
            $article_set = $na;
            $t->param(total_thread=>$#{$na} + 1);
        }
        my $new_comments = $xb->get_new_comments(-comment_no=>$bm->{comment_no},
                                                 -last_article_no=>$last_article->{article_no});
        my @new_comments;
        my %read_article;
        foreach my $c (@$new_comments) {
            $max_comment_no = $$c{comment_no} 
                if( $max_comment_no < ($$c{comment_no} || -1));

            $$c{title} = $q->escapeHTML($$c{title});
            $$c{is_owner} = $$c{uid} == $uid ? 1 : 0;
            $$c{allow_comment} = $allow_comment;
            unless ( $read_comment{ $$c{comment_id} } ) {
                if ($read_article{ $$c{article_no} }) {
                    delete $$c{article_no};
                    delete $$c{title};
                    delete $$c{artcl_name};
                    delete $$c{artcl_id};
                }
                ++$read_article{ $$c{article_no} }  if $$c{article_no};
                push @new_comments, $c;
            }
        }
        if( $max_comment_no < 0 ) { 
            $max_comment_no = $xb->max_comment_no; 
        }
        $xb->set_comment_bookmark(-board_id=>$bid, 
                                  -uid=>$uid, 
                                  -last_comment_no=>$max_comment_no );
        my $new_commentset = \@new_comments;
        $new_commentset = $xb->format_anon_list(-list=>$new_commentset)
            if ($xb->is_anonboard);
        $t->param(new_comments=> $new_commentset);
        $t->param(total_newcomments=>$#new_comments + 1);
    } elsif ($bm && $a eq 'rb') { # reset bookmark
        $xb->set_bookmark(-board_id=>$bid, -uid=>$uid);
    } elsif ($bm && $a eq 'db') { # delete bookmark
        $xb->del_bookmark(-board_id=>$bid, -uid=>$uid);
    }
}

$article_set = $xb->format_anon_list(-list=>$article_set)
    if ($xb->is_anonboard);
$t->param(article_set=>$article_set) if ($article_set);
    
################################################################################
# article list

$t->param(search_fields=>$xb->search_fields(-field=>$field));

my $al;
if ($allow_read) {
    if ($keyword && $field && $field =~ /title|id|name/) {
        $al = $xb->get_articlelist(-keyword=>$keyword,
                                   -field=>$field);
        $t->param(keyword=>$q->escapeHTML($keyword));
        $t->param(enc_keyword=>$enc_keyword);
        $t->param(field=>$field);
        if ($field eq 'title') {
            my $esc = '\\';
            $keyword =~ s/([_%'"\+\*\?\.\[\]\(\)\^\$])/$esc$1/g;
            foreach my $i (@$al) {
                $i->{$field} =~ s/($keyword)/<span class="search">$1<\/span>/gi;
            }
        }
    } elsif ($img && $img eq '1') {
        $al = $xb->get_img_articlelist;
        foreach my $i (@$al) {
            $i->{title} = $ui->substrk2($i->{title}, 10);
        }
    } else {
        $al = $xb->get_articlelist;
        $t->param(notice_list=> $xb->get_notice_articlelist);
    }
    if ($bm && exists $bm->{article_no}) {
        # reload bookmark if bookmark has been reset 
        $bm = $xb->get_bookmark(-board_id=>$bid, -uid=>$uid)
            if ($a && $a eq 'rb');

        # mark new articles
        foreach my $i (@$al) {
            $i->{new} = 'n' if ($i->{article_no} > $bm->{article_no});
        }
    }
    $al = $xb->format_anon_list(-list=>$al)
        if ($xb->is_anonboard);
    $t->param(list=>$al);
} else {
    my $msg = qq(You don't have permission to read this page.);
    unless ($auth->auth) {
      $t->param(include_login_form => 1);
      $t->param(url => $ui->cgiurl);
      $t->param(login_URL => $ui->cfg->LoginURL);
    }
    $ui->msg($msg);
}

################################################################################
# navigation 

$t->param(%{ $xb->get_pagenav(-keyword=>$enc_keyword, -field=>$field) });
$t->param(%{ $xb->get_bookmark_nav(-uid=>$uid) });

################################################################################
my $t1 = new Benchmark;
my $runtime = timestr(timediff($t1, $t0));
$t->param(runtime=>$runtime);

print $ui->output;
1;
