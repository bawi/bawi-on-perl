#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Text::Iconv;

use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $session_key = $ui->cgi->param('session');

unless ($auth->auth or $auth->auth(-session_key=>$session_key)) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $atid = $ui->cparam('atid');
my $bid = $ui->cparam('bid');
my $thumb = $ui->cparam('thumb') || 0;

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $attach = $xb->get_attach(-attach_id=>$atid, -thumb=>$thumb);

#warn("type=$$attach{content_type},filename=$$attach{filename},is_img=$$attach{is_img}");
# Content-Disposition: attachment; filename="foobar.txt"
# ~~~~~ abandon attachment type~~~
#if ($attach and $$attach{file} and $$attach{is_img} eq 'n') {
if ( 0 ) {
    # IE6.0 tend to fail to parse utf-8 hangul file names.
    my $converter = Text::Iconv->new("utf8", "euckr");
    my $euckr_filename = $converter->convert($$attach{filename});

    print $ui->cgi->header(-type=>$$attach{content_type},
                           -attachment=>$euckr_filename,
                           -Content_length=>$$attach{filesize},
                           -charset=>'euc-kr',
                           -expires=>'+3M');
    print $$attach{file};

} elsif ($attach and $$attach{filehandle} ) {
    print $ui->cgi->header(-type=>$$attach{content_type},
                           -Content_Disposition=>qq(inline; filename="$$attach{filename}"),
                           -Content_length=>$$attach{filesize},
                           -expires=>'+3M');
    my $fh = $$attach{filehandle};
    my $buffer;
    while (my $len = read($fh, $buffer, 1024_000)) {
        print $buffer;
    }
    close $fh;

} elsif ($attach and $$attach{file} ) {
    print $ui->cgi->header(-type=>$$attach{content_type},
                           -Content_Disposition=>qq(inline; filename="$$attach{filename}"),
                           -Content_length=>$$attach{filesize},
                           -expires=>'+3M');
    print $$attach{file};

} elsif ($ui->cgi->server_name ne "www.bawi.org") {
    print $ui->cgi->redirect("http://www.bawi.org/board/attach.cgi?".$ui->cgi->query_string );
} else {
    $ui->init(-template=>'error.tmpl');
    $ui->tparam(error=>"Cannot find the attach file. ID=[$atid] filename=[$$attach{filename}]");
    print $ui->output;
}
1;
