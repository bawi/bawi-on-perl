#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'msn.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $uid = $auth->uid;
my ($type, $cid) = map { $ui->cparam($_) || '' } qw(type cid);
if ($type eq 'ki') {
    my $ki = $user->ki($uid);
    my $has_im = $user->has_im($uid, 'msn');
    $ui->tparam(contact_list=>$user->im_list_msn_ki($ki))
        if ($has_im);
} elsif ($type eq 'circle' && $cid ne '' && $user->is_circle_member($cid, $uid) ) {
    $ui->tparam(contact_list=>$user->im_list_msn_circle($cid));
}

$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);
print $ui->cgi->header(-type        =>'text/xml',
                       -attachment  =>'msn.ctt',
                       -charset     => $ui->cfg->CharSet);
print $ui->template->output;

1;
