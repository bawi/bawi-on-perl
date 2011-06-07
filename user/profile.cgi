#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'profile.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui); 
my $dbh = $ui->dbh; 

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}
$ui->tparam(menu_profile=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);
my $id = $ui->cparam('id') || $auth->id;
my $profile = qq(select a.uid, a.name, a.id, b.ki, c.ename, c.affiliation, c.title, 
                        c.death, a.email, c.homepage, c.birth, 
                        c.mobile_tel, c.home_tel, c.office_tel, c.temp_tel,
                        c.wedding, c.home_address, c.count_today,
                        c.office_address, c.temp_address, 
                        c.im_msn, c.im_nate, c.im_yahoo, c.im_google,
                        c.home_map, c.office_map, c.temp_map,
                        c.greeting, c.class1, c.class2, c.class3, c.count, 
                        date_format(c.modified, "%Y-%m-%d") as modified,
                        DATE_FORMAT(a.accessed, "%Y-%m") as accessed
                 from bw_xauth_passwd as a, bw_user_ki as b, bw_user_basic as c
                 where a.uid=b.uid && a.uid=c.uid && a.id=?);

my $board = qq(select board_id, title from bw_xboard_board where id=?);

if ($id) {
    my $p = $dbh->selectrow_hashref($profile, undef, $id);
    my $uid = $$p{uid};
    if ($uid == $auth->uid) {
        $$p{is_owner} = 1;
    } else {
        $user->add_count($uid);
    }
    delete $$p{wedding} if ($$p{wedding} eq '0000-00-00');
    delete $$p{death} if ($$p{death} eq '0000-00-00');
    foreach my $i (qw(home_address office_address temp_address)) {
        $$p{$i} =~ s/\n/<br>/g;
    }

    $$p{affiliation} = join(" ", 
                           map { 
                                 my $t = $_;
                                 $t =~ s/\(주\)//g;
                                 $t =~ s/,$//g;
                                 $t =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
                                 qq(<a href="search.cgi?keyword=$t">$_</a>); 
                           } 
                               split(/\s+/, $$p{affiliation}) );
    
    $$p{has_photo} = $user->has_photo($auth->uid);
    $$p{has_phone} = $user->has_phone($auth->uid);
    $$p{has_address} = $user->has_address($auth->uid);
    $$p{has_major} = $user->has_major($auth->uid);
    $$p{has_degree} = $user->has_degree($auth->uid);
    $$p{has_circle} = $user->has_circle($auth->uid);
    $$p{has_class} = $user->has_class($auth->uid);
    foreach my $i (qw(google msn nate yahoo)) {
        $$p{"has_im_$i"} = $user->has_im($auth->uid, $i);
    }
    my $rv = $dbh->selectall_hashref($board, 'board_id', undef, $id);
    if ($rv) {
        my @board = map { $$rv{$_} } 
                        sort {$$rv{$a}->{board_id} <=> $$rv{$b}->{board_id} } 
                            keys %$rv;
        $$p{board} = \@board;
    }
    
    $$p{major} = $user->get_major($uid);
    $$p{degree} = $user->get_degree($uid);
    $$p{circle} = $user->get_circle($uid);
    $$p{class} = $$p{class1} || $$p{class2} || $$p{class3} ? 1 : 0;
    $$p{guestbook_count} = $user->get_guestbook_count($uid);
    $$p{total_count} = $user->get_total_count;
    $$p{total_count_today} = $user->get_total_count_today;
    $ui->tparam(profile=>[$p]);
}

print $ui->output;

1;
