#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Text::Iconv;
use Bawi::Auth;

use Bawi::Board;
use Bawi::Board::UI;
use Bawi::Board::Group;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->init(-template=>'boardcfg.tmpl');
$ui->tparam(HTMLTitle => "게시판 설정");
$ui->tparam(id=>$auth->id);
$ui->tparam(is_admin=>$auth->is_admin);
my $t = $ui->template;

my $board_id = $ui->cparam('board_id');
unless ($board_id) {
    $ui->msg('No board is selected.');
    print $ui->output; exit;
}

my $xb = new Bawi::Board(-cfg=>$ui->cfg, 
                         -board_id=>$board_id, 
                         -dbh=>$ui->dbh);
unless ($xb and $xb->board_id) {
    $ui->msg('Board does not exist.');
    print $ui->output; exit;
}

my $uid = $auth->uid || 0;
my $is_root = $uid == 1 ? 1 : 0;
my $is_owner = ($uid == $xb->uid) || $is_root ? 1 : 0;

$t->param(HTMLTitle => "설정 - ".$xb->title." (".$xb->id.")");
$t->param(board_id=>$board_id);
$t->param(board_title=>$xb->title);
$t->param(owner=>[{name=>$xb->name, id=>$xb->id}] );
$t->param(img=>$xb->is_imgboard);
$t->param(is_root=>$is_root);
$t->param(is_owner=>$is_owner);
$t->param(expire_days=>$xb->expire_days);

my $grp = new Bawi::Board::Group(-gid=>$xb->gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);
$t->param(path=>$grp->get_path);

unless ($is_owner) {
    $ui->msg('Only the owner or root can update configuration.');
    print $ui->output; exit;
}

my $allow_attach= $ui->cfg->AllowAttach || 0;
$t->param(AllowAttach =>$allow_attach);
my $allow_anon_board = $ui->cfg->AllowAnonBoard || $is_root;
$t->param(AllowAnonBoard =>$allow_anon_board);
my $allow_access_control = $ui->cfg->AllowAccessControl || $is_root;
$t->param(AllowAccessControl=>$allow_access_control);
my $allow_anon_access = $ui->cfg->AllowAnonAccess || $is_root;
$t->param(AllowAnonAccess=>$allow_anon_access);

my %cfg;
my $submitted = $ui->cparam('submit') ? 1 : 0;
my @field = qw(title id keyword skin expire_days is_imgboard allow_attach allow_recom allow_scrap);
push @field, qw(seq gid article_per_page page_per_page 
               attach_limit image_width thumb_width
               is_anonboard
               g_read m_read a_read g_write m_write a_write 
               g_comment m_comment a_comment); # if $is_root;
my $updated = 0;
foreach my $i (@field) {
    my @val = $ui->cgi->param($i);
    my $val = pop (@val);
    $val =~ s/^\s+|\s+$//g if defined $val;

    if ( defined $val and $val ne $xb->$i ) {
        my $check = 0;
        if ($i eq 'title') {
            #$val = $ui->cgi->escapeHTML($val);
            #my $converter = Text::Iconv->new("utf8", "euckr");
            #my $title_length = length($converter->convert($val));
            #unless ($title_length <= 32 && length($val) > 0) {
            #    ++$check;
            #    $ui->msg(qq($i should be more than 0 and less than 32 characters.));
            #}
            #$val = $ui->substrk2($val, 32);
        } elsif ($i eq 'id') {
            if ($auth->exists_id(-id=>$val)) {
                my $user = $auth->get_user(-id=>$val);
                $xb->uid($user->{uid});
                $xb->name($user->{name});
            } else {
                ++$check;
                $ui->msg(qq(User ID '$val' does not exists.));
            }
        } elsif ($i eq 'keyword') {
            unless ($val =~ /^\w+$/) {
                ++$check;
                $ui->msg(qq($i should be alphanumeric ([0-9a-zA-Z_]).));
            }
            $val = substr($val, 0, 16);
        } elsif ($i eq 'gid') {
            unless ($val =~ /^\d+$/ && $val >= 0 && $val <= 16777215) {
                ++$check;
                $ui->msg(qq($i should be a number from 0 to 16777215.));
            }
        } elsif ($i eq 'article_per_page' || $i eq 'page_per_page' || $i eq 'thumb_width') {
            unless ($val =~ /^\d+$/ && $val >= 0 && $val <= 255) {
                ++$check;
                $ui->msg(qq($i should be a number from 0 to 255.));
            }
        } elsif ($i eq 'attach_limit') {
            unless ($val =~ /^\d+$/ && $val >= 0 && $val <= 4294967295) {
                ++$check;
                $ui->msg(qq($i should be a number from 0 to 4294967295.));
            }
        } elsif ($i eq 'image_width') {
            unless ($val =~ /^\d+$/ && $val >= 0 && $val <= 65535) {
                ++$check;
                $ui->msg(qq($i should be a number from 0 to 65535.));
            }
        } elsif ($i eq 'expire_days') {
            unless ($val =~ /^\d+$/ && $val >= 0 && $val <= 36500) {
                ++$check;
                $ui->msg(qq($i should be a number from 0 to 36500.));
            }
        } elsif ($i =~ /^allow_|is_|_read|_write|_comment/) {
            $val = 0 unless $val == 1;
        } elsif ($i eq 'skin') {
            unless ($val ne '') {
                ++$check;
                $ui->msg(qq(Please select a skin.));
            }
        }
        if ($check == 0) {
            $xb->$i($val);
            ++$updated;
        }
    }
    $cfg{$i} = $xb->$i;
    #$t->param($i=>$xb->$i) unless $i eq 'skin';
}

my $skin = $xb->skin || '';
my $skinset = $ui->get_skinset;
@$skinset = map { $$_{selected} = $$_{skin} eq $skin ? 1 : 0; $_ } 
                @$skinset;
$cfg{skinset} = $skinset;
$cfg{skin}    = $skin;
#$t->param(skinset=>$skinset);
#$t->param(skin=>$skin);
$t->param(board_cfg=>[\%cfg]);

if ($updated) {
    if ($xb->save_instance) {
        $ui->msg('Updated.');
    } else {
        my $err = $ui->dbh->errstr || '';
        $ui->msg("Error: $err. Please try again.");
    }
}

print $ui->output;
1;
