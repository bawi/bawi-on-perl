#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Text::Iconv;

use Bawi::Auth;
use Bawi::Board;
use Bawi::Board::UI;
use Bawi::ImageSig;

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

if ($attach and $$attach{filehandle}) {
    my $fh = $$attach{filehandle};
    my $path = $$attach{path};

    # A row can carry is_img='y' + an image/* content_type yet hold non-raster
    # bytes -- stored raw before upload-time validation existed, or migrated by
    # z2x.pl from a filename extension. Never feed those to ImageMagick
    # (ImageTragick); serve them inert (sandbox + nosniff) like any other as-is
    # upload. $$attach{raster} is get_attach's magic-byte sniff of this very
    # handle -- the same check upload_attach runs. Content-type gate is any
    # image/*: legacy browsers stored image/pjpeg / image/x-png rows
    # (is_img='y' via substring match), and those must heal like their
    # canonical siblings; the magic sniff is the real ImageTragick gate.
    if ($$attach{is_img} eq 'y'
        && $$attach{content_type} =~ m{^image/}i
        && $$attach{raster}) {

        # $$attach{clean}: the sidecar marker, captured by get_attach BEFORE
        # it opened the filehandle (marker-then-open means the opened inode
        # is at least as new as the marker's rename; testing it here, after
        # the open, could certify pre-heal bytes as clean). Contract lives
        # at Bawi::Board::is_clean/mark_clean. Steady state is this branch
        # -- stream the stored bytes, no ImageMagick. No CSP sandbox on the
        # two raster branches: the bytes are magic-verified raster (and
        # re-encoded output on the heal path), unlike the as-is branch below.
        if ($$attach{clean}) {
            print $ui->cgi->header(
                -type => $$attach{content_type},
                -X_Content_Type_Options => 'nosniff',
                -Content_Disposition => qq(inline; filename="$$attach{filename}"),
                -Content_length => $$attach{filesize},
                -expires => '+3M'
            );
            my $buffer;
            while (my $len = read($fh, $buffer, 1024_000)) {
                print $buffer;
            }
            close $fh;
        } else {
            # Legacy file saved before upload-time stripping existed:
            # Bawi::Board::heal_attach does exactly what every view used to
            # do (Strip + re-encode), persists the result, and marks it, so
            # the ImageMagick pass runs once per file instead of per view.
            #
            # The persist DELIBERATELY rewrites the stored original: purging
            # EXIF/geodata from disk is part of the point (serving stripped
            # bytes while keeping geotagged originals would retain the
            # exposure), and it matches upload policy -- add_attach has
            # never kept originals either. What lands on disk is exactly
            # what every view has been served since the per-view strip
            # existed. Take a one-time backup of the attach tree before
            # first deploy if recovery of pre-strip originals matters --
            # and if attachment files are ever restored from a backup,
            # delete the tree's *.clean markers afterward (restored bytes
            # predate their markers; the heal re-certifies on next view).
            close $fh;
            my $cleaned_image =
                Bawi::Board::heal_attach($path, $$attach{content_type});

            if (defined $cleaned_image) {
                print $ui->cgi->header(
                    -type => $$attach{content_type},
                    -X_Content_Type_Options => 'nosniff',
                    -Content_Disposition => qq(inline; filename="$$attach{filename}"),
                    -Content_length => length($cleaned_image),
                    -expires => '+3M'
                );
                print $cleaned_image;
            } else {
                # Undecodable: nothing safe to serve (the raw bytes may
                # carry the EXIF this path exists to strip). Fail closed
                # with an empty, UNCACHED response -- a +3M expires here
                # would mask a later repair for months. heal_attach already
                # warned with the cause.
                print $ui->cgi->header(
                    -type => $$attach{content_type},
                    -X_Content_Type_Options => 'nosniff',
                    -Content_Disposition => qq(inline; filename="$$attach{filename}"),
                    -Content_length => 0,
                    -Cache_Control => 'no-store'
                );
            }
        }
    } else {
        # Non-raster bytes wearing an image/* content_type, and every other
        # type (svg, html, ...), served as-is:
        print $ui->cgi->header(
            -type => $$attach{content_type},
            # Sandbox untrusted uploads served as-is (e.g. svg, html): if opened as a
            # top-level document their scripts are blocked and origin is opaque, so a
            # malicious upload can't run same-origin JS or read the (non-HttpOnly) cookie.
            -Content_Security_Policy => 'sandbox',
            # nosniff: don't let the browser MIME-sniff an as-is upload into a
            # scriptable type (e.g. text/plain -> HTML) regardless of declared type.
            -X_Content_Type_Options => 'nosniff',
            -Content_Disposition => qq(inline; filename="$$attach{filename}"),
            -Content_length => $$attach{filesize},
            -expires => '+3M'
        );

        # Output file content
        my $buffer;
        while (my $len = read($fh, $buffer, 1024_000)) {
            print $buffer;
        }
        close $fh;
    }
} elsif ($ui->cgi->server_name ne "www.bawi.org") {
    print $ui->cgi->redirect("http://www.bawi.org/board/attach.cgi?".$ui->cgi->query_string);
} else {
    $ui->init(-template=>'error.tmpl');
    $ui->tparam(error=>"Cannot find the attach file. ID=[$atid] filename=[$$attach{filename}]");
    print $ui->output;
}
1;
