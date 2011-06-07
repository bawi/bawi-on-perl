#!/usr/bin/perl -w
use Benchmark;
my $t1 = new Benchmark;
use strict;
use warnings;
use CGI qw(:standard);

use Bawi::Auth; 
use Bawi::Main::UI;
use Bawi::Main::Note;
use Bawi::Main::RecentAccess;

my $q = new CGI;
$q->charset('utf-8'); # for proper escapeHTML.

my $ui = new Bawi::Main::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg); 
my $n = new Bawi::Main::Note(-dbh=>$ui->dbh);
my $ra = new Bawi::Main::RecentAccess(-dbh=>$ui->dbh);

my %form;
foreach my $key ($q->param()) {
	$form{ $key } = $q->escapeHTML( $q->param($key) );
}

my $t0 = $form{'t0'} || "";
my $action = $form{'action'} || "";
my $r_msg_id = $form{'r_msg_id'}|| "";
my $mbox = $form{'mbox'} || "inbox";
my $wait = $form{'wait'} || 0;

if ($auth->auth && $auth->{id}) {
    my $id = $auth->{id};
    my $uid = $auth->{uid};
    my $name = $auth->{name};

    $ra->set_last_access2( $uid, $id );
    my $notes = $n->check_new_msg($id);
    my $has_messages = ( $notes ? @{$notes} : $notes );

    print $q->header( -charset=>'utf-8', -type=>'text/html' );
    if( $has_messages > 0 ) {
        print div({class=>"note alert"}, alert_message($has_messages, $notes));
    } else {
        print comment( div({class=>"note alert"}, alert_message($has_messages, $notes)) );
    }
} else {
    print $q->header( -charset=>'utf-8', -type=>'text/html' );
    print comment( div({class=>"note alert"}, alert_message()) );
}

sub alert_message
{
  my $n = shift || -1;
  my $notes = shift;
  return a({href=>$ui->cfg->NoteURL,
            target=>"bw_message",
            onclick=>"note(''); return false;"},
            "You've got more than ten messages.") if $n > 10;
  return a({href=>$ui->cfg->NoteURL,
            target=>"bw_message",
            onclick=>"note(''); return false;"},
            "You've got $n messages.") if 1 < $n and $n <= 10;
  return a({href=>$ui->cfg->NoteURL,
            target=>"bw_message",
            onclick=>"note(''); return false;"},
            "You've got a message.") if $n == 1;
  return "You've no message." if $n == 0;
  return "You need to login first.";
}

