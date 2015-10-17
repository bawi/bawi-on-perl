#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Board;

my $ui = new Bawi::Board::UI;

my $atid = $ui->cparam('atid');

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $attach = $xb->get_attach(-attach_id=>$atid, -thumb=>1);

if ($attach and $$attach{filehandle}) {
    print $ui->cgi->header(-type=>$$attach{content_type}, -expires=>'+1M');
    my ($file, $buffer, $bytes);
    while (my $len = read($$attach{filehandle}, $buffer, 1024)) {
        $file .= $buffer;
        $bytes += $len;
    }
    close $$attach{filehandle};
    print $file;
} elsif ($ui->cgi->server_name ne "www.bawi.org") {
    print $ui->cgi->redirect("http://www.bawi.org/board/thumb.cgi?".$ui->cgi->query_string );
} else {
    $ui->init(-template=>'error.tmpl');
    $ui->tparam(error=>"Cannot find the attach file. ID=[$atid] filename=[$$attach{filename}]");
    print $ui->output;
}
1;
