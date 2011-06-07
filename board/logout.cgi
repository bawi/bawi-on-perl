#!/usr/bin/perl -w
use strict;
use lib '../lib';
use CGI;

use Bawi::Auth;
use Bawi::Board::Config;

my $q = new CGI;
my $cfg = new Bawi::Board::Config;
my $auth = new Bawi::Auth(-cfg => $cfg);

if ($auth->auth) {
  $auth->logout;
  my %cookie = %{ $auth->session_cookie };
  $cookie{-value} = '';
  $cookie{-expires} = '-1Y';
  my $cookie = $q->cookie(%cookie);
  print $q->redirect(-cookie=>$cookie, -uri=>$auth->logout_url);
} else {
  print $q->redirect($auth->logout_url);
}

exit;
