#!/usr/bin/perl

use CGI qw(:standard);
my $q = new CGI;

print header();

print <<EOF;
<HTML>
<HEAD>
<TITLE>
System Load Average
</TITLE>
</HEAD>
<BODY BGCOLOR="#ffffff" MARGINHEIGHT=5 TOPMARGIN=5 BOTTOMMARGIN=0>
<A HREF="javascript:window.location.reload();">
  <IMG SRC="graph.cgi" BORDER=0>
</A><br>
EOF

my $days = 28; # recent 21 days
my $DIR = $ENV{BAWI_PERL_HOME}."/admin/process/";
my $CWD = $ENV{BAWI_PERL_HOME}."/main/process/";

foreach my $n ( 1..$days ) {
    my @date = localtime(time  - $n * 86_400);
    my ($year, $month, $day) = ($date[5] + 1900, $date[4] + 1, $date[3]);

	my $fname = sprintf( "history/%4d-%02d-%02d.png", $year, $month, $day );
	my $lfile = sprintf( $DIR . "dat/%4d-%02d-%02d.txt", $year, $month, $day );
	if( -e $lfile ) {
		if( $q->param( 'g' ) == 1 ) {
			printf qq(<IMG src="graph.cgi?date=%4d%02d%02d">), $year, $month, $day;
		} elsif( -e $CWD . $fname ) {
			printf qq(<IMG src="$fname">);
		} else {
			printf qq(<IMG src="graph.cgi?date=%4d%02d%02d">), $year, $month, $day;
		}
	}
}
print <<EOF;
</BODY>
</HTML>
EOF
