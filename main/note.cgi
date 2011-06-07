#!/usr/bin/perl -w
use strict;
use warnings;
use CGI qw(:standard);

use lib "../lib";
use Bawi::Auth; 
use Bawi::Main::UI;
use Bawi::Main::Config;
use Bawi::Main::Note;

my $ui = new Bawi::Main::UI(-template => 'note.tmpl');
my $auth = new Bawi::Auth(-cfg => $ui->cfg); 
my $n = new Bawi::Main::Note(-dbh => $ui->dbh);

unless ($auth->auth) {
  print $auth->login_page($ui->cgiurl);
  exit (1);
}

my $q = $ui->cgi;
my $script = $q->url();

$ui->term(qw(T_PREV T_NEXT T_DELETE T_COMMENT T_SAVE T_RESET));

my %form;
$q->charset('utf-8'); # for proper escaping.
foreach my $key ($q->param()) { $form{ $key } = $q->escapeHTML( $q->param($key) ); }

my $to_id      = $form{'to'} || "";
my $to_default = $form{'to_default'} || $to_id || "";
my $msg        = $form{'msg'} || "";
my $action     = $form{'action'} || "";
my $r_msg_id   = $form{'r_msg_id'}|| "";
my $mbox    = $form{'mbox'} || "inbox";
my $wait    = $form{'wait'} || 0;
my $page    = $form{'page'} || 0;
my $crop    = $form{'crop'} || 0;

$ui->init(-template=>'_note_messages.tmpl') if $crop;

my (@alerts);
my $body = "";
my $onload = "";
my $id = $auth->{id};
my $name = $auth->{name};

# send any message
if ( $to_id ne "" and $msg ne "" ) {
  my @to_id = split(/[,;\s]+/, $to_id);
  foreach my $to ( @to_id )
  {
    my $u = $n->get_user_info_by_id($to);
    my ($to_uid, $to_name) = map { $u->{$_} } qw(uid name);
    if ($to eq "root") {
      push @alerts, {html=>qq(바위지기는 <b>webmaster\@bawi.org</b> 로 연락하시기 바랍니다.)};
    } elsif ($to_uid && $to_uid > 0) {
      my $rv = $n->send_msg($to, $to_name, $id, $name, $msg);
      push @alerts, {html=>qq(<strong>$to_name($to)</strong>님께 쪽지를 보냈습니다.)}
        if ($rv =~ /^\d+$/ && $rv > 0);
    } else {
      push @alerts, {html=>qq(<strong>$to</strong>는 존재하지 않는 아이디입니다.)};
    }
  }
}

# delete any message
if ( $r_msg_id ne "" and ($action eq "Delete" or $action eq "Reply" or $action eq "Delete+Reply")) {
  my $rv = $n->delete_msg($r_msg_id);
  push @alerts, {html=>qq(<strong>$rv</strong>개의 쪽지를 삭제했습니다.)}
    if ($rv =~ /^\d+$/  && $rv > 0);
}

# save any message
if ( $r_msg_id ne "" && $action eq "Save" || $action eq "Save+Reply") {
  my $rv = $n->save_msg($r_msg_id);
  push @alerts, {html=>qq(<strong>$rv</strong>개의 쪽지를 저장했습니다.)}
    if ($rv =~ /^\d+$/ && $rv > 0);
}

# check messages and print
my $count = $n->check_messages(-mbox=>$mbox, -id=>$id);
#warn("count=$count,mbox=$mbox,id=$id,wait=$wait");
my $rv = $n->get_messages(-mbox=>$mbox, -id=>$id, -page=>$page);
   $rv = $n->format_notes($rv);
my $page_nav = $n->get_pagenav(-page=>$page);

$ui->tparam(to_default=>$to_default);
$ui->tparam(mbox=>$mbox);
$ui->tparam('wait'=>$wait);
$ui->tparam(msg_count=>$count);
$ui->tparam(is_inbox=>($mbox eq "inbox" ? 1 : 0));
$ui->tparam(is_sent =>($mbox eq "sent"  ? 1 : 0));
$ui->tparam(notes=>$rv);
$ui->tparam(%{$page_nav});

my $body_class = "note";
if ( $count == 0 and $wait == 1 ) {
  push @alerts, {html=>qq(10초마다 새 쪽지를 확인합니다.
  [<span class="timer sec">0</span> seconds])};
  $body_class .= " reload";
}
$ui->tparam(body_class=>$body_class);

$ui->tparam(HTMLTitle=>"바위쪽지 beta");
$ui->tparam(alerts=>\@alerts);

print $ui->output;
1;
