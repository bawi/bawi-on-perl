#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Text::Markdown;

sub render {
    my $body = shift;
    $body = Text::Markdown::markdown($body);

    # Same markdown pipeline as Bawi::Board::format_article.
    my $escaped_tags = 'html body embed iframe applet script bgsound object meta head style link';
    my $tags = '(' . join("|", split(/\s+/, $escaped_tags) ) . ')'; 
    $body =~ s/<(\/?$tags)/&lt;$1/igox;
    $body =~ s/\shref\s*=\s*(["'])\s*(?:javascript|data|vbscript)\s*:[^"']*\1/ href="#"/gi;
    return $body;
}

sub assert_contains {
    my ($name, $body, $needle) = @_;
    die "$name: expected $needle\n$body\n" unless index($body, $needle) >= 0;
}

sub assert_not_contains {
    my ($name, $body, $needle) = @_;
    die "$name: did not expect $needle\n$body\n" if index($body, $needle) >= 0;
}

my $body = render("# Heading");
&assert_contains('heading', $body, '<h1>');

$body = render("**bold**");
&assert_contains('bold', $body, '<strong>');

$body = render("[x](http://a.b)");
&assert_contains('http link', $body, '<a href="http://a.b">');

$body = render("    code");
&assert_contains('code block', $body, '<pre><code>');

$body = render("<script>alert(1)</script>");
&assert_contains('script escaped', $body, '&lt;script');
&assert_not_contains('script escaped', $body, '<script');

$body = render("<iframe src=http://a.b></iframe>");
&assert_contains('iframe escaped', $body, '&lt;iframe');

$body = render("[x](javascript:alert(1))");
&assert_contains('javascript href stripped', $body, 'href="#"');
&assert_not_contains('javascript href stripped', $body, 'javascript:');

$body = render("> quoted");
&assert_contains('blockquote', $body, '<blockquote>');

$body = render("<b>hi</b>");
&assert_contains('plain b tag', $body, '<b>hi</b>');

print "ok\n";
