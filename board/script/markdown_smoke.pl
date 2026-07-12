#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Bawi::Markdown;
use Time::HiRes qw(time);

# The denylist below mirrors escape_tags' CODE FALLBACK. Production
# reads the per-board bw_xboard_board.escaped_tags column, whose schema
# default omits "head style link" -- so keep sanitization assertions to
# tags present in BOTH lists (script, iframe). The drift check below
# fails this suite if Board.pm's fallback list or href strip changes.
my $escaped_tags = 'html body embed iframe applet script bgsound object meta head style link';
my $href_strip   = 's/\shref\s*=\s*(["\'])\s*(?:javascript|data|vbscript)\s*:[^"\']*\1/ href="#"/gi;';

{
    open my $fh, '<', "$FindBin::Bin/../../lib/Bawi/Board.pm" or die "Board.pm: $!";
    local $/; my $src = <$fh>;
    my ($bd_tags) = $src =~ /\$self->\{escaped_tags\} \|\| '([^']+)'/;
    die "smoke denylist drifted from Board.pm escape_tags fallback\n"
        unless defined $bd_tags && $bd_tags eq $escaped_tags;
    # exact match, not substring: a tightened scheme list or a changed
    # replacement target must fail here (else this suite green-lights
    # sanitization behavior production no longer has).
    my ($bd_href) = $src =~ /(s\/\\shref[^\n]*\/gi;)/;
    die "smoke href strip drifted from Board.pm format_article\n"
        unless defined $bd_href && $bd_href eq $href_strip;
}

# Single source of truth: compile the drift-checked $href_strip once and
# run THAT in render(), so there is no third hand-maintained copy to drift.
my $apply_href = eval "sub { local \$_ = shift; $href_strip return \$_; }"
    or die "cannot compile href strip: $@";

sub render {
    # 77 stands in for the article id Board.pm passes (footnote anchors
    # come out as fn-77-N)
    my $body = Bawi::Markdown::render(shift, 77);

    # escape_tags denylist + href strip, as Bawi::Board::format_article
    # applies after Bawi::Markdown::render().
    my $tags = '(' . join("|", split(/\s+/, $escaped_tags) ) . ')';
    $body =~ s/<(\/?$tags)/&lt;$1/igox;
    $body = $apply_href->($body);
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
&assert_contains('fn ref sup', $body, '<sup id="fnref-77-1"><a href="#fn-77-1">1</a></sup>');
&assert_contains('fn ref second number', $body, '<a href="#fn-77-2">2</a>');
&assert_contains('fn list item', $body, '<li id="fn-77-1">첫 각주 <strong>강조</strong>');
&assert_contains('fn backlink', $body, '<a href="#fnref-77-1">&#8617;</a>');
&assert_contains('fn math in def', $body, '\(E=mc^2\)');
&assert_not_contains('fn def line removed', $body, '[^1]:');

# Korean footnote labels: anchors key on the NUMBER (byte-mode \w
# would strip hangul labels to "", colliding every anchor)
$body = render("트위스터[^주석] 그리고 구글리[^참고] 문제.\n\n[^주석]: 첫째\n[^참고]: 둘째\n");
&assert_contains('korean fn first anchor', $body, '<sup id="fnref-77-1"><a href="#fn-77-1">1</a></sup>');
&assert_contains('korean fn second anchor', $body, '<sup id="fnref-77-2"><a href="#fn-77-2">2</a></sup>');
&assert_contains('korean fn list items', $body, '<li id="fn-77-2">둘째');
&assert_not_contains('korean fn no empty anchor', $body, 'id="fn-77-"');

# unknown reference stays literal; no footnote section without defs
$body = render('허공[^nope] 참조');
&assert_contains('unknown fn ref literal', $body, '[^nope]');
&assert_not_contains('no fn section', $body, 'class="footnotes"');

# fn ref inside a fence stays literal
$body = render(qq{```\n각주[^1] 문법\n```\n\n[^1]: 정의\n});
&assert_contains('fn ref in fence literal', $body, '각주[^1] 문법');

# --- blockquote nesting fixtures ---

# fence inside a blockquote: quote prefix stripped from code, block stays
# inside the quote
$body = render(qq{> 인용 속 코드:\n>\n> ```python\n> def f(): pass\n> ```\n});
&assert_contains('quoted fence class', $body, '<pre><code class="language-python">def f(): pass');
die "quoted fence not inside blockquote:\n$body"
    unless $body =~ m{<blockquote>.*<pre><code class="language-python">.*</blockquote>}s;

# code lines keeping their own > chars beyond the quote level
$body = render(qq{> ```\n> cmd >> out.txt\n> ```\n});
&assert_contains('quoted fence redirect chars', $body, 'cmd &gt;&gt; out.txt');

# table inside a blockquote
$body = render("> | a | b |\n> |---|--:|\n> | 1 | 2 |\n");
&assert_contains('quoted table right align', $body, '<td align="right">2</td>');
die "quoted table not inside blockquote:\n$body"
    unless $body =~ m{<blockquote>.*<table>.*</blockquote>}s;

# a quoted table stops at a quote-level change
$body = render("> | a | b |\n> |---|---|\n> | 1 | 2 |\n| 3 | 4 |\n");
&assert_not_contains('level change ends table', $body, '<td>3</td>');

# --- deep-review round 1 fixtures ---

# fence info strings beyond \w: c++/c# map to prism grammar names,
# hyphenated tags pass through
$body = render(qq{```c++\nint x = v.size();\n```});
&assert_contains('c++ fence class', $body, '<pre><code class="language-cpp">int x = v.size();');
$body = render(qq{```objective-c\nid obj;\n```});
&assert_contains('hyphenated fence class', $body, 'class="language-objective-c"');

# fences are no longer <p>-wrapped (tables already were not)
$body = render(qq{```\nplain\n```});
&assert_not_contains('fence not p-wrapped', $body, '<p><pre');
$body = render(qq{> ```\n> quoted\n> ```});
&assert_not_contains('quoted fence not p-wrapped', $body, '<p><pre');

# an unbalanced $$ stays literal: the fence after it survives and
# blocks in between keep their structure
$body = render(qq{비용은 \$\$ 큽니다.\n\n## 소제목\n\n```perl\nmy \$x;\n```\n});
&assert_contains('unbalanced dollars keep heading', $body, '<h2>소제목</h2>');
&assert_contains('unbalanced dollars keep fence', $body, '<pre><code class="language-perl">');
&assert_not_contains('no leaked sentinel bytes', $body, "\x{1A}");

# display math still crosses plain line breaks (one paragraph)...
$body = render("\$\$\na + b = c\n\$\$");
&assert_contains('multiline display math', $body, "\$\$\na + b = c\n\$\$");
# ...but never a blank line
$body = render("\$\$ 시작\n\n끝 \$\$ 그리고 \$\$x\$\$");
&assert_not_contains('display math stops at blank line', $body, '시작' . "\n\n" . '끝');

# postfix currency: digit before the opening $ blocks inline math
$body = render('이건 5$짜리와 10$짜리 입니다.');
&assert_not_contains('postfix currency not math', $body, '\(');

# one $..$ cannot merge two inline code spans (content excludes `)
$body = render('변수 `$total` 과 `$price` 비교');
&assert_contains('code spans intact', $body, '<code>$total</code>');
&assert_not_contains('code spans not merged', $body, '\(total');

# \$ is a literal dollar (pandoc parity)
$body = render('세금은 \$100 정도입니다.');
&assert_contains('escaped dollar literal', $body, '세금은 $100 정도입니다.');

# user-typed sentinel bytes are stripped, not honored as tokens
$body = render("위조 \x{1A}M0M\x{1A} 토큰과 \$x\$ 수식");
&assert_contains('forged token neutralized', $body, '위조 M0M 토큰과');
&assert_contains('real math still works', $body, '\(x\)');

# javascript: URLs DISPLAYED inside a fence stay verbatim (quotes are
# entity-escaped, so the href strip cannot rewrite them)
$body = render(qq{```html\n<a href="javascript:alert(1)">x</a>\n```});
&assert_contains('js url in fence displayed', $body, 'href=&quot;javascript:alert(1)&quot;');
&assert_not_contains('js url in fence not stripped', $body, 'href="#"');

# deep quote prefixes are capped, not fatal ({0,$lvl} would die past
# 65534). Text::Markdown itself warns about deep blockquote recursion
# on such input (pre-existing) -- silence that, we only assert no die.
{
    local $SIG{__WARN__} = sub {};
    $body = render((">" x 150) . " ```\n" . (">" x 150) . " deep\n" . (">" x 150) . " ```");
}
&assert_contains('deep quote fence renders', $body, '<pre><code>');

# CRLF input end-to-end
$body = render("| a | b |\r\n|---|---|\r\n| 1 | 2 |\r\n");
&assert_contains('crlf table', $body, '<td>1</td>');

# loose task list (blank line between items -> <li><p>)
$body = render("- [ ] 하나\n\n- [x] 둘\n");
&assert_contains('loose task checkbox', $body, '<input type="checkbox" disabled');
&assert_contains('loose task keeps p', $body, '<li style="list-style-type:none"><p><input');

# --- deep-review round 2 fixtures ---

# inline $..$ wrapping a display token must not nest (would leak \x1A)
$body = render('함수 $f = \(x\)$ 로 둔다');
&assert_not_contains('inline around display no sentinel leak', $body, "\x{1A}");
&assert_not_contains('inline around display no M0M', $body, 'M0M');
&assert_contains('inner display math survives', $body, '\(x\)');

# ReDoS guard: opener-exclusion makes a dangling \( / \[ fail at the
# NEXT opener, so a body of unmatched openers is O(n), not O(n^2). This
# must hold even when a SECOND delimiter family is present (which keeps
# all alternation branches live). Wall-clock guard: the pre-fix code
# took seconds on this input; healthy is well under a second.
{
    # coarse regression tripwire (healthy ~0.15s; pre-fix O(n^2) ~2.7s
    # on this 64KB input). Generous 2s bound tolerates load spikes.
    my $t0 = time;
    $body = render(('\(x ' x 16000) . '\)\]');   # 64KB, two branches live
    die sprintf("math ReDoS regression: render took %.2fs (expected <2)\n", time - $t0)
        if time - $t0 > 2;
}
&assert_not_contains('mixed openers no sentinel', $body, "\x{1A}");
# a large display formula (~4KB, well past round-2's removed 2000-byte
# cap) shields intact -- pins the "no length cap" property
$body = render('$$' . ('a & b & c & d \\\\ ' x 250) . '$$');
&assert_contains('big formula shielded', $body, 'a & b & c & d \\\\ a');
&assert_not_contains('big formula not em', $body, '<em>');

# LaTeX row break \\[1ex] inside \[..\] must not be read as a nested \[
# opener (else the span opener is corrupted and MathJax can't render)
$body = render('\[ x_1 = 1 \\\\[1ex] y_2 = 2 \]');
&assert_contains('rowbreak bracket intact', $body, '\[ x_1 = 1 \\\\[1ex] y_2 = 2 \]');
# an ESCAPED open-paren \\( inside \(..\) must survive (pins the paren
# branch's escaped-pair -- a \\[ here would not, it never trips (?!\\\())
$body = render('\( a \\\\(x b \)');
&assert_contains('rowbreak paren intact', $body, '\( a \\\\(x b \)');
# a \\ row break right before a BLANK line must NOT let the span cross
# it (else a following heading is swallowed into shielded math source).
# Pre-fix the escaped pair ate the first newline and the span reached
# the trailing \] , swallowing the heading.
$body = render("\\[ x \\\\\n\n# 제목\n\n\\]");
&assert_contains('blank line not crossed by escaped pair', $body, '<h1>제목</h1>');

# display math with a real closer still shields
$body = render('식은 \(a+b\) 이다');
&assert_contains('paren display shielded', $body, '\(a+b\)');

# same footnote cited twice: ref ids must be unique (valid HTML)
$body = render("처음[^1] 그리고 다시[^1] 참조.\n\n[^1]: 정의\n");
&assert_contains('fn first ref id', $body, 'id="fnref-77-1"');
&assert_contains('fn repeat ref id suffixed', $body, 'id="fnref-77-1-2"');
{
    my $n = () = $body =~ /id="fnref-77-1"/g;
    die "duplicate fnref id (got $n)\n" unless $n == 1;
}

# ~~x~~ inside a table cell code span stays literal (guarded like top level)
$body = render("| a | b |\n|---|---|\n| `~~x~~` | 2 |\n");
&assert_contains('cell code keeps tildes', $body, '<code>~~x~~</code>');
&assert_not_contains('cell code no del', $body, '<del>x</del>');

# ~~x~~ inside a footnote-def code span stays literal too
$body = render("본문[^1] 참조.\n\n[^1]: 코드 `~~y~~` 유지\n");
&assert_contains('fn def code keeps tildes', $body, '<code>~~y~~</code>');

# raw <pre> with a nested <code>: ~~ after the inner </code> but still
# inside <pre> must stay literal (region captured as one unit)
$body = render('<pre>~~a~~ <code>b</code> ~~c~~</pre>');
&assert_not_contains('pre-nested-code no del', $body, '<del>');

# c++ / c# fences map to prism's canonical grammar names
$body = render(qq{```c++\nint x;\n```});
&assert_contains('cpp alias class', $body, '<pre><code class="language-cpp">');
$body = render(qq{```c#\nint x;\n```});
&assert_contains('csharp alias class', $body, '<pre><code class="language-csharp">');

print "ok\n";
