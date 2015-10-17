#!/usr/bin/perl -w
use strict;
use lib '../lib';
use CGI;

use Bawi::Auth;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg => $ui->cfg, -dbh=>$ui->dbh);

if ($auth->auth) { # access allowed
	# write cookie for mobile.
	my $cookie_bawi_mobile = CGI::Cookie->new(  -name  => 'bawi_mobile',
												-value => $ui->is_mobile_device || "iphone",
												-expires => '+1Y' );

	my %cookies = CGI::Cookie->fetch;

	print $ui->cgi->redirect( -cookie=>$cookie_bawi_mobile, 
							  -url=>$cookies{'last_url'}->value || 'http://www.bawi.org' );
} else {
  print $ui->cgi->redirect($auth->logout_url);
}

exit;
