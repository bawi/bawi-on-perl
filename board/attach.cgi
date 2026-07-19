#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Text::Iconv;
use Image::Magick;

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

    # Magic-byte sniff needs only the leading bytes (JPEG 3, PNG 8, GIF 6).
    # The seek back to 0 is load-bearing for every branch below -- they all
    # read this handle from the start.
    my $head = '';
    read($fh, $head, 8);
    seek($fh, 0, 0);

    # A row can carry is_img='y' + an image/* content_type yet hold non-raster
    # bytes -- stored raw before upload-time validation existed, or migrated by
    # z2x.pl from a filename extension. Never feed those to ImageMagick
    # (ImageTragick); serve them inert (sandbox + nosniff) like any other as-is
    # upload. is_raster_image is the same magic-byte check upload_attach uses.
    if ($$attach{is_img} eq 'y'
        && $$attach{content_type} =~ /image\/(jpeg|jpg|png|gif)/i
        && Bawi::ImageSig::is_raster_image($head)) {

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
            # Legacy file saved before upload-time stripping existed: do
            # exactly what every view used to do (Strip + re-encode), but
            # persist the result and mark it, so the ImageMagick pass runs
            # once per file instead of once per view.
            #
            # The persist DELIBERATELY rewrites the stored original: purging
            # EXIF/geodata from disk is part of the point (serving stripped
            # bytes while keeping geotagged originals would retain the
            # exposure), and it matches upload policy -- add_attach has
            # never kept originals either. What lands on disk is exactly
            # what every view has been served since the per-view strip
            # existed. Take a one-time backup of the attach tree before
            # first deploy if recovery of pre-strip originals matters.
            my $file_content = '';
            my $buffer;
            while (my $len = read($fh, $buffer, 1024_000)) {
                $file_content .= $buffer;
            }
            close $fh;

            my $im = new Image::Magick;
            # PerlMagick returns an error string only for undecodable input
            # (empirically: a truncated JPEG decodes partially with an EMPTY
            # return -- that class is indistinguishable from success, and its
            # re-encode is the same bytes every view already served).
            my $decode_err = $im->BlobToImage($file_content);

            # Strip all metadata including EXIF/geotags
            $im->Strip();

            # Maintain quality for JPEG images
            $im->Set(quality=>90) if $$attach{content_type} =~ /jpeg|jpg/i;

            my $cleaned_image = $im->ImageToBlob();

            # Persist via tmp + rename (atomic, same dir); marker only after
            # the rename lands. Every failure is non-fatal but LOUD: serve
            # the cleaned bytes (if any) and let the heal retry next view.
            # No persist on a reported decode error or empty re-encode --
            # never replace the stored file with broken output. The -e guard
            # skips the persist when del_attach unlinked the file while this
            # heal was running (don't resurrect deleted attachments).
            if ($decode_err) {
                warn "attach heal: decode failed for $path: $decode_err";
            } elsif (!(defined $cleaned_image && length $cleaned_image)) {
                warn "attach heal: empty re-encode for $path";
            } else {
                my $tmp = "$path.heal$$";
                if (open(my $out, '>', $tmp)) {
                    binmode $out;
                    print $out $cleaned_image;
                    if (close($out) && -e $path && rename($tmp, $path)) {
                        Bawi::Board::mark_clean($path);
                    } else {
                        warn "attach heal failed for $path: $!";
                        unlink $tmp;
                    }
                } else {
                    warn "attach heal failed for $path: $!";
                }
            }

            # If the re-encode produced nothing there is nothing safe to
            # serve -- the client gets an empty 200 (fail-closed: the raw
            # bytes may carry the EXIF this path exists to strip) and the
            # warn above is the diagnostic.
            print $ui->cgi->header(
                -type => $$attach{content_type},
                -X_Content_Type_Options => 'nosniff',
                -Content_Disposition => qq(inline; filename="$$attach{filename}"),
                -Content_length => length($cleaned_image || ''),
                -expires => '+3M'
            );
            print $cleaned_image if defined $cleaned_image;
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
