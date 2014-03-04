#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::User::UI;
use Bawi::Auth;

my $ui = new Bawi::User::UI(-template=>'passwd.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $mobile = Bawi::User::UI::is_mobile_device;

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->tparam(menu_profile=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

my $q = $ui->cgi;
my $t = $ui->template;

my ($oldpasswd, $newpasswd1, $newpasswd2, $expired) = map { $q->param($_) || '' } qw(oldpasswd newpasswd1 newpasswd2 expired);

$newpasswd1 = substr($newpasswd1, 0, 8);
$newpasswd2 = substr($newpasswd2, 0, 8);
if ($expired) {
    $ui->msg("비밀번호를 변경한지 $auth->{passwd_expire}일 이상 지났습니다. 비밀번호를 변경해 주세요.");
    $t->param(expired=>$expired);
}
if ($oldpasswd ne '' && $newpasswd1 ne '' && $newpasswd2 ne '') {
    if ($oldpasswd eq $newpasswd1) {
        $ui->msg('New password must be different from old password');
    } elsif ($newpasswd1 eq $newpasswd2) {
        my $rv = $auth->chpasswd(-id=>$auth->id, 
                               -oldpasswd=>$oldpasswd, 
                               -newpasswd=>$newpasswd1);
        if ($rv == 1) {
            $ui->msg('Password changed.');
            if ($expired) {
                print $q->redirect($auth->success_url);
                exit (1);
            }
        } else {
            $ui->msg('Incorrect password.');
        }
    } else {
        $ui->msg('New passwords does not match.');
    }
}
$t->param(id=>$auth->id);

$ui->tparam(HTMLTitle => "비밀번호 변경");
$ui->tparam(google_analytics => $ui->cfg->GoogleAnalytics);
$ui->tparam(note_url => $ui->cfg->NoteURL);
$ui->tparam(user_url => $ui->cfg->UserURL);
$ui->tparam(board_url => $ui->cfg->BoardURL);
$ui->tparam(news_url => $ui->cfg->NewsURL);
$ui->tparam(mobile_device => $mobile);
$ui->tparam(remote_address => $ui->cgi->remote_addr );
$ui->tparam(user_agent     => $ui->cgi->user_agent  );

print $ui->output;

1;
