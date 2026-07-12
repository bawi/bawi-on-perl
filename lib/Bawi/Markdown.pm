package Bawi::Markdown;
# Markdown rendering pipeline for category==1 articles: classic
# Text::Markdown plus the extensions the board wants on top of it.
#
#   render($body [, $uniq]) does, in order:
#     1. ``` fenced code blocks -> <pre><code class="language-X">
#        (top level or inside blockquotes; extracted FIRST so nothing
#        inside code is ever taken for math, a table, or markup;
#        prism.js in the skin does the highlighting)
#     2. MathJax spans shielded from the parser: $$..$$ \[..\] \(..\)
#        verbatim, inline $..$ emitted as \(..\) (the site MathJax
#        config, TeX-MML-AM_CHTML, has single-$ off but processes
#        \(..\)); then \$ unescapes to a literal $
#     3. footnotes: [^id] references + top-level "[^id]: text"
#        definitions -> numbered <sup> links and a trailing footnote
#        list appended after stage 8 (anchors are per-article numbers:
#        fn-<uniq>-<n>, see $uniq below)
#     4. GFM pipe tables -> <table> (Text::Markdown passes block-level
#        HTML through untouched; cell contents get span-level markdown)
#     5. Text::Markdown::markdown()
#     6. fence tokens unwrapped from the <p> the parser puts around
#        bare-text lines (a <pre> may not sit inside <p>)
#     7. ~~strikethrough~~ -> <del>, skipping <pre>/<code> regions
#     8. task lists: <li>[ ] / <li>[x] -> disabled checkboxes
#     9. shielded spans restored verbatim
#
#   $uniq: pass the article id. It namespaces footnote anchors
#   (fn-<uniq>-<n>) so several rendered articles can share one page
#   (thread view, new-articles view) without duplicate ids.
#
#   Sanitization (escape_tags denylist, href scheme strip) is NOT done
#   here -- Bawi::Board::format_article applies it after render(), so
#   math/fence/table content passes the same denylist as everything
#   else. NOTE for future MathJax upgrades: the client config must NOT
#   enable the HTML.js extension (\href, \style) -- that would make
#   $$..$$ content a client-side link sink the server-side href strip
#   never sees.
#
# Known limitations (deliberate v1 scope cuts):
#   - fences/tables work at top level and inside blockquotes, but NOT
#     inside list items: a structure-blind pre-pass cannot tell a
#     4-space-indented fence inside a list item from 4-space-indented
#     code at top level (that needs real block parsing). 8-space-
#     indented code inside a list item is native classic markdown and
#     works.
#   - blockquote nesting is capped at 32 levels (excess '>' markers are
#     dropped) to bound Text::Markdown's super-linear deep-quote cost; no
#     real quote nests that deep
#   - footnote definitions are top-level and single-line
#   - a pipe-table lookalike inside 4-space-indented code is parsed as
#     a table (use a ``` fence for code instead)
#   - escape a literal | in a table cell as \|
#   - table cells and footnote definitions are span-level context:
#     reference-style links do not resolve there, and block syntax in
#     a cell degrades
#   - a $..$ span across two cells of one table row consumes the pipe;
#     in the HEADER row the column count then mismatches the separator
#     and the whole table degrades to a paragraph, in a BODY row the
#     table survives with a mangled row. Write literal dollars in table
#     rows as \$.
#   - $..$ / [^ref] sitting entirely inside ONE inline `code span` or
#     a 4-space indented block are still transformed (``` fences are
#     fully immune; an inline $..$ can no longer MERGE two code spans,
#     since its content excludes backticks)
#   - an odd number of $$ within one paragraph mis-pairs: a stray $$
#     grabs the opening $$ of the next real display span (unbalanced-
#     delimiter matching, no balance tracking). Likewise a \[..\] /
#     \(..\) whose content ends in a backslash, when an UNBALANCED
#     same-family closer sits further downstream, can over-shield to
#     that stray closer. Both are malformed-input only; well-formed
#     (balanced) math is unaffected.
#   - a literal $$..$$ typed as \$\$..\$\$ still renders as display
#     math (the \$ unescape re-forms $$); there is no way to show a
#     literal $$ pair in markdown mode
#   - ONLY exactly ``` opens a fence; a 4+-backtick fence is not
#     recognized
#   - a fence's closing ``` may sit at any quote level (lazy
#     continuation); the opening line's prefix decides the strip level
#   - ~~..~~ cannot span an inline `code span` (the pair is split at
#     code-region boundaries and left literal). A ~~a~~ pair INSIDE a
#     tag attribute / URL is still rewritten to <del>, corrupting the
#     attribute -- write such URLs without paired tildes.

use strict;
use warnings;
use Digest::MD5 ();
use Encode ();
use Text::Markdown;

sub render {
    my ($body, $uniq) = @_;
    return $body unless defined $body;
    $uniq = defined $uniq && length $uniq ? "$uniq-" : '';

    # \x1A / \x1B are this module's internal sentinel bytes (shield
    # tokens; _split_row's literal-pipe stand-in). Neither can occur
    # in legitimate text (they are bare control bytes, never part of
    # a UTF-8 sequence), so strip them up front: a user-typed token
    # would otherwise be substituted -- or deleted -- by stage 9.
    $body =~ tr/\x{1A}\x{1B}//d;

    # Cap blockquote nesting depth. Text::Markdown's _DoBlockQuotes
    # recurses once per '>' level and re-processes the cumulative HTML at
    # each level, so deep nesting is super-linear (a crafted 200-deep
    # quote took ~20s per uncached render -- a stored DoS). Real quoting
    # is never more than a few deep; clamp a leading run of '>' markers to
    # 32, dropping the excess. Linear one-pass; downstream stages then
    # never see more than 32 levels.
    $body =~ s/^((?:>[ \t]?){32})(?:>[ \t]?)+/$1/mg;

    my @shielded;
    my $shield = sub {
        # token = \x1A M <index> M \x1A -- plain bytes that ride
        # through Text::Markdown untouched. Restored in stage 9,
        # BEFORE Board.pm's escape_tags sees the output.
        push @shielded, $_[0];
        return "\x{1A}M" . $#shielded . "M\x{1A}";
    };

    # 1. fenced code blocks, at top level or inside blockquotes. The
    #    OPENING line's "> " prefix sets the quote level; up to that
    #    many quote markers are stripped from each code line ({0,$lvl}
    #    -- at most the level, so a code line's own leading ">"
    #    survives). The closing fence may sit at any quote level (lazy
    #    continuation). The prefix is re-emitted around the token so
    #    the block stays inside the quote; stage 6 removes the <p>
    #    the parser wraps around the bare token line.
    #    Info string: first word, lowercased. prism's own language
    #    regex is /-([\w-]+)/, which would truncate "c++"/"c#" to "c",
    #    so map those to prism's canonical grammar names; other tags
    #    are kept to [\w.-] and an unknown one degrades to an unstyled
    #    block. Only exactly ``` opens a fence (4+ backticks do not).
    $body =~ s{^((?:>[ \t]?)*)```[ \t]*([^`\r\n]*)\r?\n(.*?)^(?:>[ \t]?)*```[ \t]*\r?$}{
        my ($pfx, $info, $code) = ($1, $2, $3);
        my $lvl = _quote_level($pfx);
        $lvl = 100 if $lvl > 100;   # perl {0,n} caps at 65534; no real quote nests past 100
        my ($lang) = $info =~ /^\s*(\S+)/;
        $lang = defined $lang ? lc $lang : '';
        $lang = $lang eq 'c++' ? 'cpp' : $lang eq 'c#' ? 'csharp' : $lang;
        $lang =~ s/[^\w.-]//g;
        $code =~ s/\r//g;
        $code =~ s/^(?:>[ \t]?){0,$lvl}//mg if $lvl;
        $code =~ s/&/&amp;/g;
        $code =~ s/</&lt;/g;
        $code =~ s/>/&gt;/g;
        # quotes escaped too: Board.pm's href strip must never match
        # (and falsify) URLs merely DISPLAYED inside code
        $code =~ s/"/&quot;/g;
        $code =~ s/'/&#39;/g;
        $pfx . "\n" . $pfx
            . $shield->('<pre><code'
                        . ($lang ? qq{ class="language-$lang"} : '')
                        . '>' . $code . '</code></pre>')
            . "\n" . $pfx;
    }egms;

    # 2. math spans. Display forms are shielded verbatim; a span may
    #    cross line breaks but never a BLANK line (client MathJax cannot
    #    typeset across a paragraph break anyway -- $nb below, which
    #    recognizes LF, CRLF, and bare-CR blank lines) and never
    #    a shield token (\x1A) -- so an unbalanced delimiter stays
    #    literal instead of swallowing the headings/lists/fences after
    #    it. The asymmetric forms \(..\) and \[..\] additionally exclude
    #    their OWN OPENER from the span content: a dangling \( / \[ then
    #    fails at the NEXT opener (O(gap)) instead of scanning to end of
    #    body from every opener (O(n^2) -- a stored ReDoS: 64 KB of "\("
    #    pinned a worker for seconds per uncached view). $$ is symmetric
    #    (openers pair with each other), so it needs no exclusion and no
    #    length cap -- a formula of any size shields intact.
    #    An escaped pair \\<char> is consumed as a unit FIRST, so the
    #    LaTeX row break \\[1ex] (backslash-backslash-bracket, common in
    #    matrix/aligned) is not mistaken for a nested \[ opener. That
    #    trailing char excludes \r\n: otherwise \\ right before a blank
    #    line would eat the first newline and the span would cross the
    #    paragraph break (the $nb guard is per-iteration, so a blank
    #    line must always fall to the one-char alternative to be seen).
    # not a blank line. Atomic (?>...) is load-bearing: a plain
    # (?:\r\n?|\n) lets a single CRLF re-split (\r matches, backtracks to
    # give up \n, second alt takes the \n) so one CRLF would read as a
    # blank line and wrongly block a normal multi-line formula. The
    # atomic group forbids that backtrack, so CRLF is one indivisible
    # ending -- matching LF, CRLF, and bare-CR blank lines, none else.
    my $nb = qr/(?!(?>\r\n?|\n)[ \t]*(?>\r\n?|\n))/;
    $body =~ s{(
        \$\$ (?: $nb [^\x{1A}] )+? \$\$
      | \\\[ (?: $nb (?: \\\\[^\x{1A}\r\n] | (?!\\\[) [^\x{1A}] ) )+? \\\]
      | \\\( (?: $nb (?: \\\\[^\x{1A}\r\n] | (?!\\\() [^\x{1A}] ) )+? \\\)
    )}{$shield->($1)}egsx;
    #    Inline $..$ -> \(..\), pandoc rules: non-space inside; the
    #    opening $ not preceded by a digit (keeps postfix currency
    #    "5$짜리 ... 10$짜리" as text) and the closing $ not followed
    #    by one (prefix currency "$5 ... $10"); single line; content
    #    free of $, backtick (one $..$ must not merge two `code
    #    spans`), and the shield byte \x1A (so an inline pair wrapping
    #    an already-shielded display token cannot nest -- the one-pass
    #    restore in stage 9 would otherwise leak the sentinel).
    $body =~ s/(?<![\$\\0-9])\$(?=\S)([^\$\n`\x{1A}]+?)(?<=\S)\$(?!\d)/$shield->("\\($1\\)")/eg;
    #    \$ = literal dollar (pandoc parity), unescaped now that real
    #    math has been shielded. (A literal $$..$$ typed as \$\$..\$\$
    #    still becomes $$..$$ and WILL render as display math -- see
    #    the limitations list.)
    $body =~ s/\\\$/\$/g;

    # 3. footnotes: collect top-level single-line definitions, then
    #    turn references into numbered sup links. Numbering is by
    #    first reference. Anchors use the NUMBER, not the label:
    #    byte-mode \w would strip a Korean label to "" (colliding
    #    anchors), and $uniq keeps anchors distinct when several
    #    articles render on one page.
    my (%fndef, @fnorder);
    $body =~ s{^\[\^([^\]\s]+)\]:[ \t]+(.+?)[ \t]*$}{
        $fndef{$1} = $2; '';
    }egm;
    if (%fndef) {
        my (%fnnum, %fnseen);
        $body =~ s{\[\^([^\]\s]+)\]}{
            if (exists $fndef{$1}) {
                # first sight: push returns the new length of
                # @fnorder, i.e. this footnote's 1-based number
                my $n = $fnnum{$1} ||= push @fnorder, $1;
                # a label cited more than once must not repeat the ref
                # id (invalid HTML); suffix repeats fnref-<n>-2, -3...
                # The definition's backlink points at the first cite.
                my $k = ++$fnseen{$1};
                my $refid = $k == 1 ? "fnref-$uniq$n" : "fnref-$uniq$n-$k";
                qq{<sup id="$refid"><a href="#fn-$uniq$n">$n</a></sup>};
            } else {
                "[^$1]";   # no such definition: leave it literal
            }
        }eg;
    }

    # 4. pipe tables
    $body = _pipe_tables($body);

    # 5. classic markdown
    $body = Text::Markdown::markdown($body);

    # 6. a token holding BLOCK html (a fence) that ended up alone in a
    #    paragraph: drop the invalid <p> wrapper (math tokens are
    #    inline content and keep theirs)
    $body =~ s{<p>(\x{1A}M(\d+)M\x{1A})</p>}{
        my ($tok, $idx) = ($1, $2);   # the inner match below clobbers $1/$2
        ($shielded[$idx] || '') =~ /^<pre>/ ? $tok : "<p>$tok</p>";
    }eg;

    # 7. strikethrough outside code regions
    $body = _del_outside_code($body);

    # 8. task lists (GFM): checkbox display only, bullet suppressed
    $body =~ s{<li>(\s*<p>)?\s*\[([ xX])\]\s+}{
        '<li style="list-style-type:none">' . ($1 || '')
        . '<input type="checkbox" disabled'
        . (lc($2) eq 'x' ? ' checked' : '') . '> '
    }eg;

    # 3b. the footnote list itself, appended last so its content may
    #     hold shielded math (restored by stage 9 below)
    if (@fnorder) {
        my $fn = qq{<div class="footnotes"><hr /><ol>};
        for my $i (1 .. @fnorder) {
            $fn .= qq{<li id="fn-$uniq$i">} . _span_md($fndef{$fnorder[$i-1]})
                 . qq{ <a href="#fnref-$uniq$i">&#8617;</a></li>};
        }
        $body .= $fn . '</ol></div>';
    }

    # 9. restore shielded spans
    $body =~ s/\x{1A}M(\d+)M\x{1A}/$shielded[$1]/g;

    return $body;
}

# --- render cache validity model (the ONE canonical statement of it) ----
# Bawi::Board::format_article caches render() output in bw_xboard_body_html,
# one row per article; a row is valid iff its body_md5 equals
# cache_key($body) below. So:
#   * a body edit changes the key -> that article's row is overwritten on
#     its next read (self-healing; no eviction anywhere)
#   * ANY change that alters render() OUTPUT -- this module, the vendored
#     lib/Text/Markdown.pm, or deeper (system Text::Balanced) -- MUST bump
#     $CACHE_VERSION, or every already-cached article keeps serving the
#     OLD rendering indefinitely. Backstop: the smoke suite fingerprints a
#     fixed corpus and fails on an unbumped output change to any construct
#     THAT CORPUS COVERS ("render fingerprint" in markdown_smoke.pl).
#     Nothing runs it automatically -- it is a run-before-deploy check,
#     and it cannot see a system-library (Text::Balanced/perl) upgrade
#     that shifts output with no source diff. The bump stays a judgment
#     the editor owns; the fingerprint only catches the accident.
#   * render() is deterministic in its two inputs ($body, $uniq=article_id)
#     with ONE known exception: email autolinks (<x\@y.z>) are rand()-
#     obfuscated by Text::Markdown::_EncodeEmailAddress. Caching freezes
#     one obfuscation per article -- display-equivalent and still
#     harvester-hostile, so deliberately NOT folded into the key. The
#     per-article dimension (footnote anchors fn-<id>-N) is carried by
#     the row PK, not by this hash; both inputs are thus in the row key.
#     If render() ever gains another input, it must be folded into
#     cache_key or the cache will serve output computed for other values
#     of it.
our $CACHE_VERSION = 1;   # paired with ($want_ver,$want_fp) in
                          # markdown_smoke.pl -- a bump must update BOTH

sub cache_key {
    my ($body) = @_;
    my $key = "$CACHE_VERSION:$body";
    # octet callers -- the only production class, DB bodies -- hash RAW,
    # so the stored body_md5 is hand-reproducible, e.g. a SQL audit via
    # MD5(CONCAT('1:', body)). A decoded-string caller is encoded first,
    # only so md5_hex cannot croak ("Wide character") -- the same
    # conditional guard as Text::Markdown::_md5_utf8. NOT a
    # canonicalization: decoded and octet forms of the same text hash
    # differently, so every caller must pass the same representation
    # (today: raw DB octets, everywhere).
    $key = Encode::encode('utf8', $key) if Encode::is_utf8($key);
    return Digest::MD5::md5_hex($key);
}

sub _del {
    my $t = shift;
    $t =~ s/(?<!~)~~(?=\S)(.+?)(?<=\S)~~(?!~)/<del>$1<\/del>/g;
    return $t;
}

# ~~strikethrough~~ everywhere EXCEPT inside <pre>/<code> regions, so
# `~~x~~` in a code span stays literal. Used by stage 7 and _span_md
# (a cell/footnote-def may hold an inline <code> span too). A ~~ pair
# cannot span a code region -- the split breaks it (documented limit).
# A region body excludes its OWN further opener so a dangling (unclosed)
# one fails at the next opener instead of scanning to end of string from
# every opener -- else this is the same O(n^2) stored ReDoS as the math
# stage (a body of unclosed "<code" is plantable, since escape_tags does
# not denylist pre/code). It must NOT exclude the sibling opener: a
# <pre> body legitimately contains a nested <code> (the canonical
# <pre><code>..</code></pre> shape), which must be captured as one
# region so ~~ after the inner </code> stays literal.
sub _del_outside_code {
    my $t = shift;
    return join '', map {
        /^<(?:pre|code)\b/i ? $_ : _del($_)
    } split /(
        <pre\b  (?: (?! <pre\b ) . )*? <\/pre>
      | <code\b (?: (?! <code\b ) . )*? <\/code>
    )/six, $t;
}

# span-level markdown for a single-line fragment (table cells,
# footnote definitions): render, unwrap the <p>
sub _span_md {
    my $t = Text::Markdown::markdown($_[0]);
    $t =~ s/^\s*<p>//;
    $t =~ s/<\/p>\s*$//s;
    $t =~ s/\s+$//;
    return _del_outside_code($t);
}

# "> > text" -> ("> > ", "text"); prefix is empty at top level
sub _split_prefix {
    my ($pfx, $rest) = $_[0] =~ /^((?:>[ \t]?)*)(.*)$/;
    return ($pfx, $rest);
}

sub _quote_level {
    my $n = () = $_[0] =~ />/g;
    return $n;
}

sub _split_row {
    my $r = shift;
    $r =~ s/^\s*\|//;
    $r =~ s/\|\s*$//;
    $r =~ s/\\\|/\x{1B}/g;    # \| = literal pipe inside a cell
    return map {
        my $c = $_;
        $c =~ s/\x{1B}/|/g;
        $c =~ s/^\s+//;
        $c =~ s/\s+$//;
        $c;
    } split(/\|/, $r, -1);
}

sub _pipe_tables {
    my $body = shift;
    my @lines = split /\r?\n/, $body, -1;
    my @out;
    for (my $i = 0; $i <= $#lines; $i++) {
        # tables work at top level (empty prefix) and inside
        # blockquotes: all rows must sit at the same quote level, and
        # the emitted <table> line keeps the prefix so it stays
        # inside the quote
        my ($pfx, $rest) = _split_prefix($lines[$i]);
        if ($rest =~ /\|/ && $i < $#lines) {
            # a lone "|" splits to an empty list -- not a table header
            my @hdr = _split_row($rest);
            my ($pfx2, $rest2) = _split_prefix($lines[$i+1]);
            my @sep = (@hdr && $rest2 =~ /\|/
                       && _quote_level($pfx2) == _quote_level($pfx))
                      ? _split_row($rest2) : ();
            if (@sep && @sep == @hdr && !grep { !/^:?-+:?$/ } @sep) {
                my @align = map {
                    /^:-*:$/ ? 'center' : /-:$/ ? 'right' : /^:/ ? 'left' : ''
                } @sep;
                my $attr = sub { $align[$_[0]] ? qq{ align="$align[$_[0]]"} : '' };
                my $html = '<table><thead><tr>';
                $html .= '<th' . $attr->($_) . '>' . _span_md($hdr[$_]) . '</th>'
                    for 0 .. $#hdr;
                $html .= '</tr></thead><tbody>';
                my $j = $i + 2;
                while ($j <= $#lines) {
                    my ($pj, $rj) = _split_prefix($lines[$j]);
                    last unless _quote_level($pj) == _quote_level($pfx)
                             && $rj =~ /\|/;
                    my @row = _split_row($rj);
                    $html .= '<tr>';
                    $html .= '<td' . $attr->($_) . '>'
                             . _span_md(defined $row[$_] ? $row[$_] : '')
                             . '</td>'
                        for 0 .. $#hdr;
                    $html .= '</tr>';
                    $j++;
                }
                $html .= '</tbody></table>';
                # blank(-in-quote) lines around the block so
                # Text::Markdown hashes it as raw block HTML instead
                # of wrapping it in <p>
                push @out, $pfx, $pfx . $html, $pfx;
                $i = $j - 1;   # resume at $j, the first non-row line
                               # (the for-loop's ++ lands there)
                next;
            }
        }
        push @out, $lines[$i];
    }
    return join("\n", @out);
}

1;
