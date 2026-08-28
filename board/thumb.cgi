#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board::UI;
use Bawi::Board;
use Bawi::Auth;

my $ui = new Bawi::Board::UI;
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

my $atid = $ui->cparam('atid');

my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $attach = $xb->get_attach(-attach_id=>$atid, -thumb=>1);

# Thumbnails are board content: full files go through attach.cgi's auth
# gate, but this CGI served any atid to anyone (PR #34). Guests may fetch
# a thumbnail only off boards that grant anonymous read (a_read=1, the
# same predicate as read.cgi's shell guard); members keep today's
# behavior. A row whose board is gone fails closed for guests; a no-row
# atid skips the gate -- there is nothing to leak -- and keeps the
# pre-existing not-found path.
if ($attach) {
    my $bxb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh,
                              -board_id=>$$attach{board_id});
    unless ($auth->auth || ($bxb->a_read || 0) == 1) {
        print $auth->login_page($ui->cgiurl);
        exit (1);
    }
}

if ($attach and $$attach{filehandle}) {
    # This is the thumbnail URL the templates actually emit, so it takes
    # part in the .clean sidecar contract (see Bawi::Board::is_clean):
    # save_thumbnail has stripped-and-marked thumbs since upload-time
    # stripping landed, but thumbnails from before then can still carry
    # EXIF -- heal those once, exactly like attach.cgi does for full
    # files. $$attach{raster} is get_attach's magic sniff of this handle;
    # non-raster bytes never reach ImageMagick.
    if ($$attach{is_img} eq 'y'
        && !$$attach{clean}
        && $$attach{raster}) {
        close $$attach{filehandle};
        my $healed =
            Bawi::Board::heal_attach($$attach{path}, $$attach{content_type});
        if (defined $healed) {
            print $ui->cgi->header(-type=>$$attach{content_type},
                                   -X_Content_Type_Options=>'nosniff',
                                   -expires=>'+1M');
            print $healed;
        } else {
            # undecodable: fail closed, uncached (heal_attach warned)
            print $ui->cgi->header(-type=>$$attach{content_type},
                                   -X_Content_Type_Options=>'nosniff',
                                   -Content_length=>0,
                                   -Cache_Control=>'no-store');
        }
    } else {
        print $ui->cgi->header(-type=>$$attach{content_type}, -expires=>'+1M');
        my ($file, $buffer, $bytes);
        while (my $len = read($$attach{filehandle}, $buffer, 1024)) {
            $file .= $buffer;
            $bytes += $len;
        }
        close $$attach{filehandle};
        print $file;
    }
} elsif ($ui->cgi->server_name ne "www.bawi.org") {
    print $ui->cgi->redirect("http://www.bawi.org/board/thumb.cgi?".$ui->cgi->query_string );
} else {
    $ui->init(-template=>'error.tmpl');
    $ui->tparam(error=>"Cannot find the attach file. ID=[$atid] filename=[$$attach{filename}]");
    print $ui->output;
}
1;
