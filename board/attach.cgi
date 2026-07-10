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
    
    # Check if this is an image type that could contain EXIF data
    if ($$attach{is_img} eq 'y' && $$attach{content_type} =~ /image\/(jpeg|jpg|png|gif)/i) {
        # Read the entire file content
        my $file_content = '';
        my $buffer;
        while (my $len = read($fh, $buffer, 1024_000)) {
            $file_content .= $buffer;
        }
        close $fh;

        # A row can carry is_img='y' + an image/* content_type yet hold non-raster
        # bytes -- stored raw before upload-time validation existed, or migrated by
        # z2x.pl from a filename extension. Never feed those to ImageMagick
        # (ImageTragick); serve them inert (sandbox + nosniff) like any other as-is
        # upload. is_raster_image is the same magic-byte check upload_attach uses.
        if (Bawi::ImageSig::is_raster_image($file_content)) {
            # Process with ImageMagick to strip metadata
            my $im = new Image::Magick;
            $im->BlobToImage($file_content);

            # Strip all metadata including EXIF/geotags
            $im->Strip();

            # Maintain quality for JPEG images
            $im->Set(quality=>90) if $$attach{content_type} =~ /jpeg|jpg/i;

            # Get processed image data
            my $cleaned_image = $im->ImageToBlob();

            # Update filesize
            my $new_size = length($cleaned_image);

            # Output the cleaned image
            print $ui->cgi->header(
                -type => $$attach{content_type},
                -Content_Disposition => qq(inline; filename="$$attach{filename}"),
                -Content_length => $new_size,
                -expires => '+3M'
            );
            print $cleaned_image;
        } else {
            # Non-raster bytes wearing an image/* content_type: serve as-is, sandboxed.
            print $ui->cgi->header(
                -type => $$attach{content_type},
                -Content_Security_Policy => 'sandbox',
                -X_Content_Type_Options => 'nosniff',
                -Content_Disposition => qq(inline; filename="$$attach{filename}"),
                -Content_length => length($file_content),
                -expires => '+3M'
            );
            print $file_content;
        }
    } else {
        # For non-image files or image types unlikely to have EXIF, serve normally
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
        
        # Reset file handle to beginning (just in case)
        seek($fh, 0, 0);
        
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
