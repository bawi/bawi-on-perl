#!/usr/bin/perl -w
use warnings;
use strict;

use CGI;

use lib '../lib';
use Bawi::Board::Config;

my $q = new CGI;
print $q->header;

foreach my $k (sort keys %ENV) {
  print $k,"\t",$ENV{$k},"<BR>\n";
}
