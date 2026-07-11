#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Bawi::Markdown;

sub render {
    my $body = Bawi::Markdown::render(shift);

    # escape_tags denylist + href strip, as Bawi::Board::format_article
    # applies after Bawi::Markdown::render().
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

# --- fenced code block fixtures ---

# ```lang fence -> <pre><code class="language-..."> with entities escaped,
# and $ inside code never becomes math
$body = render(qq{```perl\nmy \$x = <STDIN>;\nprint "\$x & \$y";\n```});
&assert_contains('fence language class', $body, '<pre><code class="language-perl">');
&assert_contains('fence escapes angle', $body, 'my $x = &lt;STDIN&gt;;');
&assert_contains('fence escapes amp', $body, '&amp;');
&assert_not_contains('fence dollar not math', $body, '\(');

# bare fence -> plain <pre><code>
$body = render(qq{```\nplain block\n```});
&assert_contains('bare fence', $body, '<pre><code>plain block');

# $$ inside a fence stays literal (MathJax skips <code>)
$body = render(qq{```\n\$\$x\$\$\n```});
&assert_contains('math in fence literal', $body, '$$x$$');

# markdown markup inside a fence stays literal
$body = render(qq{```\n# not a heading\n```});
&assert_not_contains('heading in fence literal', $body, '<h1>');

# --- pipe table fixtures ---

my $table = "| 변수 | 의미 | 노름 |\n|:-----|:----:|-----:|\n| \$Z\$ | **정칙** | 1 |\n";
$body = render($table);
&assert_contains('table built', $body, '<table><thead><tr><th align="left">변수</th>');
&assert_contains('table center align', $body, '<th align="center">의미</th>');
&assert_contains('table right align', $body, '<td align="right">1</td>');
&assert_contains('table cell strong', $body, '<td align="center"><strong>정칙</strong></td>');
&assert_contains('table cell math', $body, '<td align="left">\(Z\)</td>');
&assert_not_contains('table not p-wrapped', $body, '<p><table');

# escaped pipe in a cell; prose with pipes but no separator is not a table
$body = render("| a\\|b | c |\n|---|---|\n| 1 | 2 |\n");
&assert_contains('escaped pipe in cell', $body, '<th>a|b</th>');
$body = render("this | that\nother | thing\n");
&assert_not_contains('prose pipes not table', $body, '<table');

# --- strikethrough fixtures ---

$body = render('~~틀린 내용~~ 이렇게 지웁니다.');
&assert_contains('strikethrough', $body, '<del>틀린 내용</del>');

$body = render('code `~~x~~` keeps tildes');
&assert_not_contains('no del in code span', $body, '<del>');

$body = render("    ~~x~~ indented code");
&assert_not_contains('no del in code block', $body, '<del>');

# --- task list fixtures ---

$body = render("- [ ] 할 일\n- [x] 끝난 일\n");
&assert_contains('task unchecked', $body, '<input type="checkbox" disabled> 할 일');
&assert_contains('task checked', $body, '<input type="checkbox" disabled checked> 끝난 일');
&assert_contains('task bullet suppressed', $body, '<li style="list-style-type:none">');

$body = render('[ ] 목록 아님');
&assert_not_contains('bracket outside list not task', $body, '<input');

# --- footnote fixtures ---

$body = render("본문[^1] 이고 다시[^note] 참조.\n\n[^1]: 첫 각주 **강조**\n[^note]: 둘째 \$E=mc^2\$ 각주\n");
&assert_contains('fn ref sup', $body, '<sup id="fnref-1"><a href="#fn-1">1</a></sup>');
&assert_contains('fn ref second number', $body, '<a href="#fn-note">2</a>');
&assert_contains('fn list item', $body, '<li id="fn-1">첫 각주 <strong>강조</strong>');
&assert_contains('fn backlink', $body, '<a href="#fnref-1">&#8617;</a>');
&assert_contains('fn math in def', $body, '\(E=mc^2\)');
&assert_not_contains('fn def line removed', $body, '[^1]:');

# unknown reference stays literal; no footnote section without defs
$body = render('허공[^nope] 참조');
&assert_contains('unknown fn ref literal', $body, '[^nope]');
&assert_not_contains('no fn section', $body, 'class="footnotes"');

# fn ref inside a fence stays literal
$body = render(qq{```\n각주[^1] 문법\n```\n\n[^1]: 정의\n});
&assert_contains('fn ref in fence literal', $body, '각주[^1] 문법');

print "ok\n";
