#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'edsig.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $xb = new Bawi::Board(-ui=>$ui);
my $t = $ui->template;

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->tparam(menu_profile=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

my $uid = $auth->uid;
my $sig = $ui->cparam('sig') || '';
if ($sig) {
    if (length($sig) > 500) {
        $ui->msg(qq(Signature is too long and not saved.));
    } else {
        my $rv = $xb->edit_sig(-uid=>$uid, -sig=>$sig);
        if ($rv == 1) {
            $ui->msg(qq(Saved.));
        } else {
            $ui->msg($ui->dbh->errstr);
        }
    }
}

#my $db_sig = $sig || $xb->get_sig(-uid=>12102);
my $db_sig = $sig || $xb->get_sig(-uid=>$uid);
$t->param(sig=>$db_sig);
my $preview = join "<br \/>",
  map {
    $_ = $xb->escape_tags($_);
    $_ = $xb->make_hyperlink($_);
  } split (/\r?\n/, $db_sig);
$t->param(preview=>$preview);

print $ui->output;
1;
