#!/usr/bin/perl -w
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Bawi::Markdown;
use Digest::MD5 ();   # the render-fingerprint block calls md5_hex directly
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

# deep quote nesting is clamped to 32 levels: renders fast (no super-
# linear Text::Markdown recursion) and emits at most 32 nested
# blockquotes, not 150. Also a fence still renders inside the (clamped)
# quote. Timing tripwire: pre-cap this hung for seconds.
{
    my $t0 = time;
    $body = render((">" x 150) . " ```\n" . (">" x 150) . " deep\n" . (">" x 150) . " ```");
    die sprintf("deep-quote perf regression: %.2fs (expected <1)\n", time - $t0)
        if time - $t0 > 1;
}
&assert_contains('deep quote fence renders', $body, '<pre><code>');
{
    my $n = () = $body =~ /<blockquote>/g;
    die "quote depth not clamped (got $n nested blockquotes)\n" if $n > 32;
}

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
# bare-CR (classic-Mac) blank line must block too, not just LF/CRLF
$body = render("\\[ x \\\\\r\r# 제목\r\r\\]");
&assert_contains('bare-CR blank line not crossed', $body, '<h1>제목</h1>');
# a SINGLE CRLF soft break inside a display span must still CROSS (shield)
# -- browsers POST CRLF, so this is the normal multi-line-formula path
$body = render("\\[\r\na + b\r\n\\]");
&assert_contains('single CRLF soft break shields', $body, "\\[\r\na + b\r\n\\]");

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

# --- render cache preconditions (Board.pm's bw_xboard_body_html rows) ---
# Board.pm caches render() output keyed on Bawi::Markdown::cache_key +
# the article_id PK. Sound only while render() is deterministic in
# (body, uniq) -- pinned here (modulo the documented rand() email-
# autolink exception; see the validity model in Bawi/Markdown.pm). The
# DB plumbing itself (SELECT/REPLACE, hit-vs-miss) has no DB in this
# harness and is deliberately out of smoke's scope; verify it on the
# test mirror when the cache path changes (PR #15 records such a run).
{
    my $src = "# 캐시\n\n**굵게** \$x_i\$ 그리고 [^1] 참조.\n\n[^1]: 정의\n";
    die "render() not deterministic -- DB cache would serve stale variants\n"
        unless Bawi::Markdown::render($src, 42) eq Bawi::Markdown::render($src, 42);
    die "cache_key broken -- Board.pm keys cache rows on it\n"
        unless Bawi::Markdown::cache_key($src) =~ /^[0-9a-f]{32}$/;
    die "cache_key ignores the body\n"
        if Bawi::Markdown::cache_key($src) eq Bawi::Markdown::cache_key("$src ");
    # uniq must change the output (footnote anchors), so Board.pm must
    # never share a cached render across articles: the key includes
    # article_id via the row PK
    &assert_contains('uniq in anchors', Bawi::Markdown::render($src, 99), 'fn-99-1');
}

# --- render fingerprint: backstop for CACHE_VERSION bumps -----------------
# A pipeline change that alters render() output WITHOUT a CACHE_VERSION
# bump makes every cached article silently serve the OLD rendering until
# its next edit. This fingerprint catches the ACCIDENTAL form of that,
# with known limits (be honest with yourself about them):
#   * it covers exactly the constructs in THIS corpus -- an output change
#     to an uncovered edge passes green. Extending pipeline features
#     should extend the corpus.
#   * nothing runs this automatically (no CI in this repo): it is a
#     run-before-deploy check.
#   * a mismatch can also mean this HOST differs (system Text::Balanced /
#     perl version), not that someone edited the pipeline.
#   * it cannot force the bump: greening it by recording a new
#     fingerprint while leaving CACHE_VERSION alone ships the stale-cache
#     bug anyway. Reviewers: a $want_fp change and a CACHE_VERSION bump
#     must land in the same diff.
# When it fires on an intentional change: 1) bump $CACHE_VERSION in
# lib/Bawi/Markdown.pm, 2) RE-RUN this suite, 3) record the (version,
# fingerprint) pair the re-run prints -- the pair printed by the FIRST
# failure still carries the pre-bump version.
# (Corpus has no email autolinks -- those are rand()-obfuscated.)
{
    my $corpus = join "\n\n",
        '# 제목 heading',
        '**bold** *em* `code` ~~del~~ 한국어',
        "> quote\n>> nested",
        ('>' x 33) . ' deep quote at the 32-level clamp boundary',
        "- [ ] task\n- [x] done",
        "| a | b |\n|---|--:|\n| \$x\$ | [l](http://e.x/) |",
        "```c++\nint x;\n```",
        "```perl\nmy \$x = 1;\n```",
        'inline $a_i$ and $$\int f$$ and \(c\)',
        '\[ x_1 \\\\[1ex] y_2 \]',
        '가격은 5$ 그리고 $5 (currency stays text)',
        "cite[^f]\n\n[^f]: def **md**",
        "<pre>\nraw &amp; block\n</pre>",
        'text <span>inline html</span> &amp; entity';
    my $fp = Digest::MD5::md5_hex(Bawi::Markdown::render($corpus, 7));
    my ($want_ver, $want_fp) = (1, '874b937320c9740e34cc091ca6a8ab57');
    if ($Bawi::Markdown::CACHE_VERSION ne $want_ver or $fp ne $want_fp) {
        die "render fingerprint mismatch: expected (v$want_ver, $want_fp),\n"
          . "got (v$Bawi::Markdown::CACHE_VERSION, $fp).\n"
          . "Intentional output change -> bump CACHE_VERSION in Bawi/Markdown.pm,\n"
          . "re-run this suite, and record the pair the RE-RUN prints (the pair\n"
          . "above still carries the pre-bump version). Unintentional -> the\n"
          . "rendering pipeline changed by accident.\n";
    }
}

# --- failure-budget divergence class (documented tradeoff, pinned) --------
# 8+ FAILING block openers (closers exist ahead, so the guard lets the
# extractor run; nesting never balances, so every attempt fails) followed
# by a block that WOULD have matched: the budget disables extraction, so
# the trailing block degrades to text instead of raw block HTML. This is
# the one accepted output divergence of the DoS patch -- if a re-vendor
# or budget tweak changes it, this fixture must be revisited.
{
    # a raw-block extraction SUCCESS emits the block bare at top level; a
    # degraded (budget-skipped) block goes through paragraph forming and
    # comes out "<p><pre>"-wrapped -- that wrapper is the signature the
    # two asserts below key on.
    my $b = ("<div>\nfiller line\n\n" x 9)      # 9 unclosed <div> openers
          . "</div>\n\n"                        # one closer: guard passes, attempts run+fail
          . "<pre>\nbudget victim\n</pre>\n";   # would-have-matched block
    $body = render($b);
    &assert_contains('budget victim text survives', $body, 'budget victim');
    &assert_contains('trailing block degraded (documented)', $body, '<p><pre>');
    # control -- same shape below the budget (2 failing openers): the
    # trailing block must still extract as bare raw block HTML
    $body = render(("<div>\nfiller line\n\n" x 2)
                   . "</div>\n\n<pre>\ncontrol block\n</pre>\n");
    &assert_contains('control block raw', $body, "<pre>\ncontrol block\n</pre>");
    &assert_not_contains('control block not degraded', $body, '<p><pre>');
}

# --- block-opener flood (stored DoS, Text::Markdown local patch) ----------
# Floods of block-tag openers drove _HashHTMLBlocks SUPER-linear
# (Text::Balanced rescans/recurses to EOF per opener): ~120s at 50KB, plus
# a deep-recursion warning flood under -w. The vendored guard now (1)
# memoizes the "no closer ahead" skip so an unclosed flood is O(n), (2)
# skips a NET-UNCLOSED tag when the remaining body exceeds $EXTRACT_TAIL_CAP
# (4096 B), and (3) caps failed extractions at 8/pass. Each shape below was
# super-linear (multi-second to minutes) before the fix and is now well
# under 1s -- these fixtures pin the SKIP paths, so <2s is a real bound with
# margin. (Note: the parser's INHERENT cost for any ~64KB body is ~2.5-3.4s
# regardless of guards -- benign "x\n\n" x21000 is 2.6s in stock -- so <2s
# is NOT a general 64KB bound, only a bound on these guarded skip shapes.
# The inherent linear floor is deferred to the systemic budget; see
# IMPROVEMENTS_PLAN.md parking lot.) All fit bw_xboard_body.body (TEXT, 64KB).
{
    my %flood = (
        # sparse unclosed <pre> (the original round-1 shape)
        'sparse-pre'      => "<pre>\nsome text follows here\nmore text\n\n"
                             x (int(50_000 / 40) + 1),
        # dense net-unclosed openers + large tail (large-tail guard)
        'dense-noclose'   => "<p>\n" x 16000,
        'dense-endcloser' => ("<p>\n" x 16000) . "</p>\n",
        'closer-behind'   => "</div>\n" . ("<div>\n" x 16000),
        # balanced open/close COUNT but every closer is BEHIND the openers,
        # so none is ahead: net_unclosed is FALSE (large-tail guard does NOT
        # fire), so the no-closer index() SKIP (guard 2) is the only thing
        # that keeps this off the extractor. Removing that skip -> stock
        # >20s (this <2s bound hard-pins it on any host). The memo on top is
        # an O(n)-vs-O(n^2) polish on the (already-skipped, already-safe)
        # index probe: without it the probe reruns per line (~3.1s at 63KB
        # on the slow deploy host; only ~0.7s on a fast dev box, so this
        # wall-clock bound pins the memo only where it renders slowly).
        'noclose-behind'  => ("</p>\n" x 7000) . ("<p>\n" x 7000),
        # SUB-CAP imbalance (only 8 net-unclosed) but a large tail: the
        # round-3 fixed-cap guard MISSED this (imbalance 8 < 64) -> ~4s.
        # The large-tail guard catches it. (Round-4 HIGH.)
        'subcap-far'      => ("<p>\n" x 9) . "</p>\n" . ("word " x 13000),
        'subcap-midband'  => ("<p>\n" x 64) . "</p>\n" . ("word " x 12000),
        # attribute-hostile tail (no '>'): each doomed attempt scanned it
        # super-linearly -- >20s before the large-tail guard. (Round-4 HIGH.)
        'attr-hostile'    => ("<p>\n" x 9) . "</p>\n" . ("<x a=" x 12500),
        # the documented residual: a net-unclosed flood whose expensive tail
        # is in the LAST <CAP bytes still runs, but is budget+CAP bounded
        'residual-tail'   => ("word " x 12000) . "\n" . ("<x a=" x 800),
    );
    for my $name (sort keys %flood) {
        my $t0 = time;
        render($flood{$name});
        die sprintf("block-opener DoS regression [%s]: %.2fs (expected <2)\n",
                    $name, time - $t0)
            if time - $t0 > 2;
    }
    # the flooded lines still render (as text), nothing is swallowed
    $body = render("<pre>\nsome text follows here\n\n" x 2000);
    &assert_contains('flood lines survive', $body, 'some text follows');
    # a balanced raw block among many still extracts (imbalance 0, guard
    # must not touch well-formed HTML)
    $body = render("<pre>\nraw &amp; block\n</pre>\n\npara\n");
    &assert_contains('closed pre still raw block', $body, "<pre>\nraw &amp; block\n</pre>");
    $body = render("<div>x</div>\n" x 500);
    &assert_contains('balanced repeats still raw', $body, '<div>x</div>');
}

print "ok\n";
