#!/usr/bin/perl -w
use strict;
use lib "../lib";
use CGI;
use Bawi::Auth; 
use Bawi::User::UI;

my $UPDIR = "/home/bawi/photo_attach";

my $q = new CGI;
my $ui = new Bawi::User::UI(-template=>'upload_photo.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh); 

$ui->tparam(menu_profile=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

unless ($auth->auth) {
  print $auth->login_page($ui->cgi->url(-query=>1));
  exit(1);
}

my $id = $auth->id;
chomp($id);

if($q->param('image')) {
	my $uid = $auth->uid;
	local *local_fh; my $fh = *local_fh; undef *local_fh;
	$fh = $q->upload('image');
	my $type = $q->uploadInfo($fh)->{'Content-Type'};

	if (!$fh && $q->cgi_error) {
		print $q->header(-status=>$q->cgi_error);
		exit 0;
	}

	if( ($type eq 'image/jpeg') || ($type eq 'image/pjpeg') ) {
		my $out = "$UPDIR/$uid.jpg";
		my($bytesread, $buffer);
		open(OUTFILE,"> $out") or die("Can't open file $out: $!\n");
		while($bytesread=read($fh,$buffer,1024)) {
			print OUTFILE $buffer;
		}
		close OUTFILE;
    $ui->tparam(upload_success=>1);
    $ui->tparam(uid=>$uid);
	} else {
		print "<CENTER><H5>JPEG 형식만 지원합니다.</H5></CENTER>";
		print &uploadform;
	}
} else {
  $ui->tparam(upload_form=>1);
}

print $ui->output;
1;
