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
#     3. GFM pipe tables -> <table> (Text::Markdown passes block-level
#        HTML through untouched; cell contents get span-level markdown)
#     4. Text::Markdown::markdown()
#     5. ~~strikethrough~~ -> <del>, skipping <pre>/<code> regions
#     6. shielded spans restored verbatim
#
#   Sanitization (escape_tags denylist, href scheme strip) is NOT done
#   here -- Bawi::Board::format_article applies it after render(), so
#   math/fence/table content passes the same denylist as everything else.
#
# ponytail ceilings (v1): fences/tables are recognized at top level only
# (not inside lists/blockquotes); a pipe-table lookalike inside 4-space
# indented code is parsed as a table (use a ``` fence for code instead);
# escape a literal | in a table cell as \|; a single $..$ can eat a |
# if one math span is written across two cells.
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

    # 1. fenced code blocks
    $body =~ s{^```[ \t]*(\w*)[ \t]*\r?\n(.*?)^```[ \t]*\r?$}{
        my ($lang, $code) = ($1, $2);
        $code =~ s/\r//g;
        $code =~ s/&/&amp;/g;
        $code =~ s/</&lt;/g;
        $code =~ s/>/&gt;/g;
        $shield->('<pre><code'
                  . ($lang ? qq{ class="language-$lang"} : '')
                  . '>' . $code . '</code></pre>');
    }egms;

    # 2. math spans; $$..$$ / \[..\] / \(..\) verbatim, then inline $..$
    #    (pandoc rules: non-space inside, closing $ not followed by a
    #    digit, single line -- keeps "$5 ... $10" as currency)
    $body =~ s/(\$\$.+?\$\$|\\\[.+?\\\]|\\\(.+?\\\))/$shield->($1)/egs;
    $body =~ s/(?<![\$\\])\$(?=\S)([^\$\n]+?)(?<=\S)\$(?!\d)/$shield->("\\($1\\)")/eg;

    # 3. pipe tables
    $body = _pipe_tables($body);

    # 4. classic markdown
    $body = Text::Markdown::markdown($body);

    # 5. strikethrough outside code regions
    $body = join '', map {
        /^<(?:pre|code)\b/i ? $_ : _del($_)
    } split /(<pre\b.*?<\/pre>|<code\b.*?<\/code>)/si, $body;

    # 6. restore shielded spans
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

sub _pipe_tables {
    my $body = shift;
    my @lines = split /\r?\n/, $body, -1;
    my @out;
    for (my $i = 0; $i <= $#lines; $i++) {
        my @hdr;
        if ($lines[$i] =~ /\|/ && $i < $#lines && $lines[$i+1] =~ /\|/
            && (@hdr = _split_row($lines[$i]))) {
            my @sep = _split_row($lines[$i+1]);
            if (@sep == @hdr && @sep && !grep { !/^:?-+:?$/ } @sep) {
                my @align = map {
                    /^:-*:$/ ? 'center' : /-:$/ ? 'right' : /^:/ ? 'left' : ''
                } @sep;
                my $attr = sub { $align[$_[0]] ? qq{ align="$align[$_[0]]"} : '' };
                my $html = '<table><thead><tr>';
                $html .= '<th' . $attr->($_) . '>' . _cell_span($hdr[$_]) . '</th>'
                    for 0 .. $#hdr;
                $html .= '</tr></thead><tbody>';
                my $j = $i + 2;
                while ($j <= $#lines && $lines[$j] =~ /\|/) {
                    my @row = _split_row($lines[$j]);
                    $html .= '<tr>';
                    $html .= '<td' . $attr->($_) . '>'
                             . _cell_span(defined $row[$_] ? $row[$_] : '')
                             . '</td>'
                        for 0 .. $#hdr;
                    $html .= '</tr>';
                    $j++;
                }
                $html .= '</tbody></table>';
                # blank lines around the block so Text::Markdown hashes it
                # as raw block HTML instead of wrapping it in <p>
                push @out, '', $html, '';
                $i = $j - 1;
                next;
            }
        }
        push @out, $lines[$i];
    }
    return join("\n", @out);
}

1;
