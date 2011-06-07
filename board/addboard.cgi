#!/usr/bin/perl -w
use strict;
use lib '../lib';
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

my ($gid, $keyword, $title, $skin, $save) = map { $ui->cparam($_) || undef } qw( gid keyword title skin save);

$gid = 1 unless ($gid);
$ui->init(-template=>'addboard.tmpl');
$ui->tparam(HTMLTitle => "게시판 생성");

$ui->tparam(gid=>$gid) if ($gid);
my $grp = new Bawi::Board::Group(-gid=>$gid, -cfg=>$ui->cfg, -dbh=>$ui->dbh);

my $allow_board = $grp->authz(-uid   => $auth->uid,
                              -ouid  => $grp->uid,
                              -gperm => $grp->g_board,
                              -mperm => $grp->m_board,
                              -aperm => $grp->a_board);


################################################################################
## main
################################################################################

if ($auth->uid == 1 || $ui->cfg->AllowAddBoard) {
    $ui->tparam(is_root=>1);
    $ui->tparam(skinset=>$ui->get_skinset);
    if ($gid && $keyword && $title && $skin) {
        if ($gid =~ /^\d+$/ && 
            $keyword =~ /^[a-zA-Z_0-9]+$/ && length($keyword) <= 16 &&
            length($title) <= 32) {

                my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);  
                my $rv = $xb->add_board(-gid     => $gid,   
                                        -keyword => $keyword,   
                                        -title   => $title,  
                                        -skin    => $skin,  
                                        -uid     => $auth->uid,  
                                        -id      => $auth->id,  
                                        -name    => $auth->name);  
                if ($rv && $rv == 1) {  
                    my $bid = $xb->get_board_id(-keyword=>$keyword) || 0;  
                    print $ui->cgi->redirect("read.cgi?bid=$bid");  
                    exit (1);  
                } else {  
                    $ui->msg("The keyword is used by other board.");  
                    $ui->tparam(title=>$title);  
                }  
        } else {
            $ui->msg('Incorrect keyword or title. Keyword must be an alphanumeric word up to 16 characters. Board Name can be any word up to 32 characters.');
        }
    } elsif ($save && $save eq '1') {
        $ui->msg('All fields are required.');
    }
} else {
    $ui->msg('Please login as root.');
}
print $ui->output;
1;
