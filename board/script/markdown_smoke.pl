#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Text::Markdown;

sub render {
    my $body = shift;

    # Same markdown pipeline as Bawi::Board::format_article.
    my @math;
    my $shield = sub { push @math, $_[0]; "\x{1A}M" . $#math . "M\x{1A}" };
    $body =~ s/(\$\$.+?\$\$|\\\[.+?\\\]|\\\(.+?\\\))/$shield->($1)/egs;
    $body =~ s/(?<![\$\\])\$(?=\S)([^\$\n]+?)(?<=\S)\$(?!\d)/$shield->("\\($1\\)")/eg;
    $body = Text::Markdown::markdown($body);
    $body =~ s/\x{1A}M(\d+)M\x{1A}/$math[$1]/g;

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

# --- MathJax shield fixtures ---

# bare TeX in prose stays literal (no delimiters, no MathJax -- unchanged)
$body = render('반정칙 변수인 \bar{Z}를 사용한다.');
&assert_contains('bare tex literal', $body, '\bar{Z}');

# inline $..$ emitted as \(..\) (site MathJax config processes \(..\) inline)
$body = render('변수인 $\bar{Z}$를 사용한다.');
&assert_contains('inline dollar to paren', $body, '\(\bar{Z}\)');
&assert_not_contains('inline dollar consumed', $body, '$');

# $$..$$ survives verbatim: no <em> from _ subscripts after braces
$body = render('$$\bar{Z}_\alpha \bar{W}_\beta$$');
&assert_contains('display underscores intact', $body, '$$\bar{Z}_\alpha \bar{W}_\beta$$');
&assert_not_contains('display underscores intact', $body, '<em>');

# \[..\] and \(..\) no longer eaten by backslash-escape processing
$body = render('\[ Z_\alpha \bar{Z}^\alpha = 0 \]');
&assert_contains('bracket display intact', $body, '\[ Z_\alpha \bar{Z}^\alpha = 0 \]');
$body = render('여기서 \(\bar{Z}\) 는 반정칙 변수다.');
&assert_contains('paren inline intact', $body, '\(\bar{Z}\)');

# \\ row separators survive inside display math
$body = render('$$\begin{pmatrix} a \\\\ b \end{pmatrix}$$');
&assert_contains('matrix row sep intact', $body, 'a \\\\ b');

# currency stays currency (pandoc closing rules)
$body = render('커피는 $5 이고 케이크는 $10 이다.');
&assert_not_contains('currency not math', $body, '\(');

# markdown still works around shielded math
$body = render('**중요** $x_i$ 입니다');
&assert_contains('bold beside math', $body, '<strong>');
&assert_contains('bold beside math', $body, '\(x_i\)');

# $$ inside an indented code block round-trips literally (MathJax skips <code>)
$body = render("    \$\$x\$\$");
&assert_contains('math in code literal', $body, '<pre><code>');
&assert_contains('math in code literal', $body, '$$x$$');

# escape_tags denylist still applies to shielded math content
$body = render('$$<script>alert(1)</script>$$');
&assert_contains('script in math escaped', $body, '&lt;script');
&assert_not_contains('script in math escaped', $body, '<script');

print "ok\n";
