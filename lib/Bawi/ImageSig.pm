package Bawi::ImageSig;
################################################################################
# Raster-image signature sniffing by magic bytes.
#
# Deliberately dependency-free and a raw byte check -- it must NEVER call
# Image::Magick (Ping/Read/BlobToImage), because parsing the untrusted input is
# the very ImageTragick surface this guard exists to keep bytes away from.
#
# Single source of truth for "is this really a raster image?", shared by the
# board attachment path (jpeg/png/gif) and the profile-photo paths (jpeg only),
# which previously each carried their own copy of the same magic-byte check.
################################################################################
use strict;

# leading magic-byte signature -> canonical format name
my @SIGNATURE = (
    [ 'jpeg', qr/\A\xFF\xD8\xFF/ ],       # JPEG SOI
    [ 'png',  qr/\A\x89PNG\r\n\x1A\n/ ],  # PNG signature
    [ 'gif',  qr/\AGIF8[79]a/ ],          # GIF87a / GIF89a
);

# Return the canonical format name of $bytes' leading signature, or undef.
sub sniff {
    my $bytes = shift;
    return undef unless defined $bytes;
    for my $s (@SIGNATURE) {
        return $s->[0] if $bytes =~ $s->[1];
    }
    return undef;
}

# True when $bytes begins with a real JPEG/PNG/GIF magic number.
sub is_raster_image { return defined sniff($_[0]) ? 1 : 0; }

# True only for a real JPEG (for the jpeg-only profile-photo paths).
sub is_jpeg { my $f = sniff($_[0]); return (defined $f && $f eq 'jpeg') ? 1 : 0; }

1;
