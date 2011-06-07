#!/usr/bin/perl -w
use Benchmark;
my $t1 = new Benchmark;
use strict;
use warnings;
use CGI;

my $q = new CGI;

print $q->header(-charset=>'utf-8');
print <<HTML;
<html>
<head>
<title>바위쪽지 beta</title>
<link rel="stylesheet" type="text/css" href="/css/bawi.css" />
<meta http-equiv="pragma" content="no-chache">
<meta http-equiv="chache-control" content="no-chache">
</head>
<body marginheight="0" leftmargin="0" topmargin="0" bottommargin="0" marginwidth="0" rightmargin="0">
<TABLE BORDER=0 CELLPADDING=3 CELLSPACING=0 WIDTH="100%" HEIGHT="100%">
<TR><TD CLASS="tcolhead"><IMG SRC="/image/note.gif"> 바위쪽지 beta</TD></TR>
<TR><TD HEIGHT=99%>
<table border=0 align=center width=400><tr><td>
폭탄 쪽지로 인하여 당분간 쪽지 서비스를 중지합니다.
[<A HREF="http://www.bawi.org/x/read.cgi?bid=1&aid=964334&p=276" TARGET="bawi_main">관련글</A>]
</td></tr></table>
</TD></TR>
</TABLE>
HTML

print $q->end_html();
