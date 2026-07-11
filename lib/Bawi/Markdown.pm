package Bawi::Markdown;
# Markdown rendering pipeline for category==1 articles: classic
# Text::Markdown plus the extensions the board wants on top of it.
#
#   render($body) does, in order:
#     1. ``` fenced code blocks -> <pre><code class="language-X">
#        (classic Markdown only knows 4-space indentation; fences are
#        extracted first so nothing inside code is ever taken for math,
#        a table, or markup; prism.js in the skin does the highlighting)
#     2. MathJax spans ($$..$$ \[..\] \(..\) and inline $..$) shielded
#        from the parser; inline $..$ is emitted as \(..\) because the
#        site MathJax config (TeX-MML-AM_CHTML) has single-$ off but
#        already processes \(..\) -- no client config change
#     3. footnotes: [^id] references + top-level "[^id]: text"
#        definitions -> numbered <sup> links and a trailing footnote list
#     4. GFM pipe tables -> <table> (Text::Markdown passes block-level
#        HTML through untouched; cell contents get span-level markdown)
#     5. Text::Markdown::markdown()
#     6. ~~strikethrough~~ -> <del>, skipping <pre>/<code> regions
#     7. task lists: <li>[ ] / <li>[x] -> disabled checkboxes
#     8. shielded spans restored verbatim
#
#   Sanitization (escape_tags denylist, href scheme strip) is NOT done
#   here -- Bawi::Board::format_article applies it after render(), so
#   math/fence/table content passes the same denylist as everything else.
#
# ponytail ceilings (v1): fences/tables work at top level and inside
# blockquotes, but NOT inside list items -- that would need real block-
# structure parsing (4-space indent inside a list item already means
# "code block" in classic markdown); 8-space-indented code inside a list
# item is native and works. Footnote definitions are top-level and
# single-line. A pipe-table lookalike inside 4-space indented code is
# parsed as a table (use a ``` fence for code instead); escape a literal
# | in a table cell as \|; a single $..$ can eat a | if one math span is
# written across two cells; $..$ and [^ref] inside inline `code spans`
# and 4-space blocks are still transformed (fences are fully immune).
use strict;
use warnings;
use Text::Markdown;

sub render {
    my $body = shift;
    return $body unless defined $body;

    my @shielded;
    my $shield = sub {
        push @shielded, $_[0];
        return "\x{1A}M" . $#shielded . "M\x{1A}";
    };

    # 1. fenced code blocks, at top level or inside blockquotes: an
    #    optional uniform "> " prefix is captured, stripped from the code
    #    lines, and re-emitted around the shield token so the rendered
    #    block stays inside the quote
    $body =~ s{^((?:>[ \t]?)*)```[ \t]*(\w*)[ \t]*\r?\n(.*?)^(?:>[ \t]?)*```[ \t]*\r?$}{
        my ($pfx, $lang, $code) = ($1, $2, $3);
        my $lvl = () = $pfx =~ /(>)/g;
        $code =~ s/\r//g;
        $code =~ s/^(?:>[ \t]?){0,$lvl}//mg if $lvl;
        $code =~ s/&/&amp;/g;
        $code =~ s/</&lt;/g;
        $code =~ s/>/&gt;/g;
        $pfx . "\n" . $pfx
            . $shield->('<pre><code'
                        . ($lang ? qq{ class="language-$lang"} : '')
                        . '>' . $code . '</code></pre>')
            . "\n" . $pfx;
    }egms;

    # 2. math spans; $$..$$ / \[..\] / \(..\) verbatim, then inline $..$
    #    (pandoc rules: non-space inside, closing $ not followed by a
    #    digit, single line -- keeps "$5 ... $10" as currency)
    $body =~ s/(\$\$.+?\$\$|\\\[.+?\\\]|\\\(.+?\\\))/$shield->($1)/egs;
    $body =~ s/(?<![\$\\])\$(?=\S)([^\$\n]+?)(?<=\S)\$(?!\d)/$shield->("\\($1\\)")/eg;

    # 3. footnotes: collect top-level single-line definitions, then turn
    #    references into numbered sup links (numbered by first reference)
    my (%fndef, @fnorder);
    $body =~ s{^\[\^([^\]\s]+)\]:[ \t]+(.+?)[ \t]*$}{
        $fndef{$1} = $2; '';
    }egm;
    if (%fndef) {
        my %fnnum;
        $body =~ s{\[\^([^\]\s]+)\]}{
            if (exists $fndef{$1}) {
                my $id = $1;
                $fnnum{$id} ||= push @fnorder, $id;
                (my $safe = $id) =~ s/[^\w-]//g;
                qq{<sup id="fnref-$safe"><a href="#fn-$safe">$fnnum{$id}</a></sup>};
            } else {
                "[^$1]";
            }
        }eg;
    }

    # 4. pipe tables
    $body = _pipe_tables($body);

    # 5. classic markdown
    $body = Text::Markdown::markdown($body);

    # 6. strikethrough outside code regions
    $body = join '', map {
        /^<(?:pre|code)\b/i ? $_ : _del($_)
    } split /(<pre\b.*?<\/pre>|<code\b.*?<\/code>)/si, $body;

    # 7. task lists (GFM): checkbox display only, bullet suppressed
    $body =~ s{(<li>)(\s*<p>)?\s*\[([ xX])\]\s+}{
        '<li style="list-style-type:none">' . ($2 || '')
        . '<input type="checkbox" disabled'
        . (lc($3) eq 'x' ? ' checked' : '') . '> '
    }eg;

    # footnote list appended last (content may hold shielded math)
    if (@fnorder) {
        my $fn = qq{<div class="footnotes"><hr /><ol>};
        for my $id (@fnorder) {
            (my $safe = $id) =~ s/[^\w-]//g;
            $fn .= qq{<li id="fn-$safe">} . _cell_span($fndef{$id})
                 . qq{ <a href="#fnref-$safe">&#8617;</a></li>};
        }
        $body .= $fn . '</ol></div>';
    }

    # 8. restore shielded spans
    $body =~ s/\x{1A}M(\d+)M\x{1A}/$shielded[$1]/g;

    return $body;
}

sub _del {
    my $t = shift;
    $t =~ s/(?<!~)~~(?=\S)(.+?)(?<=\S)~~(?!~)/<del>$1<\/del>/g;
    return $t;
}

# span-level markdown for a table cell: render, unwrap the <p>
sub _cell_span {
    my $t = Text::Markdown::markdown($_[0]);
    $t =~ s/^\s*<p>//;
    $t =~ s/<\/p>\s*$//s;
    $t =~ s/\s+$//;
    return _del($t);
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

sub _quote_level {
    my $n = () = $_[0] =~ /(>)/g;
    return $n;
}

sub _pipe_tables {
    my $body = shift;
    my @lines = split /\r?\n/, $body, -1;
    my @out;
    for (my $i = 0; $i <= $#lines; $i++) {
        # tables work at top level (empty prefix) and inside blockquotes:
        # all rows must sit at the same quote level, and the emitted
        # <table> line keeps the prefix so it stays inside the quote
        my ($pfx, $rest) = $lines[$i] =~ /^((?:>[ \t]?)*)(.*)$/;
        my @hdr;
        if ($rest =~ /\|/ && $i < $#lines && (@hdr = _split_row($rest))) {
            my ($pfx2, $rest2) = $lines[$i+1] =~ /^((?:>[ \t]?)*)(.*)$/;
            my @sep = ( _quote_level($pfx2) == _quote_level($pfx)
                        && $rest2 =~ /\|/ ) ? _split_row($rest2) : ();
            if (@sep && @sep == @hdr && !grep { !/^:?-+:?$/ } @sep) {
                my @align = map {
                    /^:-*:$/ ? 'center' : /-:$/ ? 'right' : /^:/ ? 'left' : ''
                } @sep;
                my $attr = sub { $align[$_[0]] ? qq{ align="$align[$_[0]]"} : '' };
                my $html = '<table><thead><tr>';
                $html .= '<th' . $attr->($_) . '>' . _cell_span($hdr[$_]) . '</th>'
                    for 0 .. $#hdr;
                $html .= '</tr></thead><tbody>';
                my $j = $i + 2;
                while ($j <= $#lines) {
                    my ($pj, $rj) = $lines[$j] =~ /^((?:>[ \t]?)*)(.*)$/;
                    last unless _quote_level($pj) == _quote_level($pfx)
                             && $rj =~ /\|/;
                    my @row = _split_row($rj);
                    $html .= '<tr>';
                    $html .= '<td' . $attr->($_) . '>'
                             . _cell_span(defined $row[$_] ? $row[$_] : '')
                             . '</td>'
                        for 0 .. $#hdr;
                    $html .= '</tr>';
                    $j++;
                }
                $html .= '</tbody></table>';
                # blank(-in-quote) lines around the block so Text::Markdown
                # hashes it as raw block HTML instead of wrapping in <p>
                push @out, $pfx, $pfx . $html, $pfx;
                $i = $j - 1;
                next;
            }
        }
        push @out, $lines[$i];
    }
    return join("\n", @out);
}

1;
