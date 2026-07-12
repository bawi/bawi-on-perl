# Bawi Improvements Plan — SVG auto-embed · 내가 추천한 글 · Markdown

*2026-07-10. Investigation by Claude (Fable 5) with two code-survey agents; all
file:line references verified against `origin/main` (f902e7c + open PRs #8/#9).
Execution model: Claude authors specs/gates, vets on the Docker mirror, and owns
git/PRs; Codex (gpt-5.5) implements the bounded coding tasks. This file is
local-only (untracked), following the CAREER_FEATURE_SPEC.md precedent.*

**Standing constraints (owner policy)**
- Lightweight, few dependencies, fast serving, no heavy JS/network — every
  design below is server-side-first and adds zero client JS.
- `main/search2.cgi` stays split and menu-hidden (FULLTEXT load unknown).
- Privacy gates: quid-pro-quo `has_*`, resolved to the stringent side.

**Already shipped while planning** (state assumed by the specs below)
- PR #8 `feature/career-search`: career-aware people search + stringent
  quid-pro-quo matching + `(전)` past-org display + display-gate consistency.
- PR #9 `feature/pagination-fixes`: real board-page `p` links, `p` clamping,
  count/list join agreement, `(총 N건)`, `search3.cgi`→`search2.cgi`.

---

## 1. SVG attach links → `<img>` auto-embed  — size S (one line + mirrors)

**Current state.** All URL→embed logic for both article bodies and comments is
one function: `Bawi::Board::make_hyperlink`. The image branch at
`lib/Bawi/Board.pm:2759` matches `\.(?:jpg|jpeg|gif|png)$` case-insensitively
against the **tail of the whole URL** — which works for
`attach.cgi?atid=…;name=/foo.png` because `_attach.tmpl` always puts
`name=/<filename>` last. `.svg` falls through to the plain-link return at
`:2776`. The user-reported URL (`…;name=/gallup_….svg`) ends in `.svg`, so it
will match once added.

**Why it's safe.** PR #7 already made `attach.cgi` serve SVG inline as
`image/svg+xml` with `Content-Security-Policy: sandbox` + nosniff
(`board/attach.cgi:83-107`), and SVG referenced via `<img>` cannot execute
script in any browser regardless. `is_img` stays `'n'` (never touches
ImageMagick — the ImageTragick guard is untouched).

**Change.**
1. `lib/Bawi/Board.pm:2759`: `jpg|jpeg|gif|png` → `jpg|jpeg|gif|png|svg`.
   Covers articles **and** comments (one shared path).
2. Optional mirrors (decide: probably yes for consistency): the independent
   copies in `lib/Bawi/User.pm:1073` (signatures; also lacks `jpeg`) and
   `lib/Bawi/Main/Note.pm:333` (notes; also lacks `jpeg`) — both also
   `http://`-only. Minimal option: leave them; they're not where users report
   the gap.

**Nuance.** No thumbnail exists for SVG (thumbnails are raster-only), so the
`<img>` loads the full sandboxed attach.cgi response — same as PR #7's
attachment-list rendering. lightbox `rel` attribute works as for other images.

**Status: SHIPPED as PR #10** (`feature/svg-autoembed`, ce235a3) — mirror-
verified (attach.cgi svg, case `.SVG`, `.png` regression all render `<img>`).

**Owner decision (grill 2026-07-10):** the legacy `make_hyperlink` copies in
`Bawi::User` (signatures) and `Bawi::Main::Note` (쪽지) stay untouched — both
are `http://`-only relics with a bigger https gap; parked (see §5).

---

## 2. 내가 추천한 글 보기 (my recommendations page) — size M−

**Data model (verified).** `bw_xboard_recom` has `(uid, article_id, PK(article_id,uid))`
in the checked-in schema (`board/sql/bx.sql:277-281`) **plus** production-only
columns `rectime` (never in any schema file!) and `retracttime`
(`db/20220903_add_retraction.sql`). Retraction is a **soft mark**:
`retract_recommender` sets `retracttime=NOW()` (`lib/Bawi/Board.pm:1043-1052`);
active recommendation ⇔ `retracttime IS NULL`. No `board_id` and no title in
the table — a JOIN to `bw_xboard_header` is mandatory.

**A dead helper already exists.** `get_recom_articlelist`
(`lib/Bawi/Board.pm:615-640`) does exactly the needed 3-table join but has
**zero callers** and **no retracttime filter**. Either revive it (+`AND
b.retracttime IS NULL`, + a `get_tot_recom_by_uid` count modeled on
`get_tot_scrap_by_uid` `:2622-2628`) or keep SQL inline in the new CGI
(matches `myarticle.cgi` house style). **Recommendation: inline in the CGI**,
delete or fix the dead helper opportunistically.

**Model page: `myarticle.cgi`, not `read_scrap.cgi`** (the scrapbook path
depends on the self-described-temporary `init_scrap_board` hack,
`Board.pm:2444-2457`).

**Permission/deleted-article model** (mirrors scrapbook precedent, no new
code): the list shows titles even for boards the viewer can't read or
soft-deleted articles (placeholder title `[[ 작성자가 삭제하였습니다. ]]`);
`read.cgi` enforces `authz` on click-through (`board/read.cgi:80-111`). The
list is the viewer's **own** recommendations — no quid-pro-quo needed.

**Owner decisions (grill 2026-07-10):** retract stays permanently blocking
(intentional tombstones — do NOT "fix" get_recommender); retracted rows are
**shown greyed with (철회)** rather than hidden; ordering **rectime DESC**
(NULL-rectime legacy rows sink last, article_id DESC tiebreak).

**Spec for Codex (bounded):**
- **Create `board/myrecom.cgi`** — clone of post-PR#9 `myarticle.cgi`
  (base on 08e8b70, which has the CAST-AS-SIGNED board-page expression):
  - count: `SELECT count(*) FROM bw_xboard_recom r, bw_xboard_header a WHERE
    r.article_id=a.article_id && r.uid=?` — retracted rows count too (they're
    listed); plus a second `SUM(r.retracttime IS NOT NULL)` for the 철회 count
    (join to header so orphaned recom rows can't create phantom pages;
    optional `&& a.board_id=?` branch like the model).
  - listing: recom `r` JOIN header `a` LEFT JOIN board `c`, same select list
    as myarticle (incl. the board-page expression from PR #9/08e8b70), plus
    `DATE_FORMAT(r.rectime,'%y/%m/%d') as rectime` and
    `DATE_FORMAT(r.retracttime,'%y/%m/%d') as retracttime`;
    `WHERE r.uid=?
     ORDER BY (r.rectime IS NULL), r.rectime DESC, r.article_id DESC`.
  - keep the 16/10 pagination block as-is (consistency with siblings).
- **Create `board/skin/default/myrecom.tmpl`** — clone of myarticle.tmpl:
  title `내가 추천한 글 보기`, header link `myrecom.cgi`, board2 column links
  `myrecom.cgi?bid=…`, header count `(총 <tmpl_var total>건, 철회 <tmpl_var
  retracted>건)`, `_page_nav_special.tmpl`. Retracted rows: `<tmpl_if
  retracttime>` → add a dimmed style (inline `style="opacity:.5"` or an
  existing muted class if one exists in style.css) and suffix the title with
  `(철회 <tmpl_var retracttime>)`; row remains a working read.cgi link.
  Show rectime in the date column (tooltip keeps created_str).
- **Modify** `board/skin/default/bookmark.tmpl` (after `:58`) and
  `bookmarkgrp.tmpl` (after `:48`): one `<li class="item">` block each,
  linking `myrecom.cgi`, placed after the mycomment entries (alongside
  Scrapbook, as requested).
- **Schema hygiene (include in same PR):** add `rectime datetime default
  NULL` + `retracttime datetime default NULL` to the `bw_xboard_recom`
  definitions in `board/sql/bx.sql` and `bx.reset.sql` so fresh installs match
  the running code (today a fresh `bx.sql` install breaks `add_recommender`,
  which INSERTs `rectime`). **No production migration needed** — prod already
  has both columns.

**Gates.** Mirror seed has recommendations? (check `bw_xboard_recom` count;
seed a few incl. one retracted and one NULL-rectime legacy row). Verify:
retracted rec renders greyed with (철회 date) and still links; NULL-rectime
rows sort last; counts (총/철회) match; click-through lands on the right
board page (08e8b70 expression); menu items render in both bookmark pages;
`perl -c` in-container.

**Magnitude: small.** 2 new files (clones), 2 one-line menu edits, 2 schema
files touched. One Codex task; Claude vets on mirror.

---

## 3. Markdown rendering support — size L (phased)

### Current pipeline facts (all verified)
- Bodies are stored **raw** (`add_article` `Board.pm:938-940`) and rendered on
  **every view**: `format_article` (`:1131-1155`) = per-line `escape_tags` →
  `make_hyperlink` → `make_quote_coloring`, joined with `<br />`. Comments:
  `format_commentset` (`:1457-1466`) with `escape_comment_tags`.
- The board is **intentionally HTML-permissive**: `escape_tags` (`:2697-2704`)
  only neutralizes a denylist (`html body embed iframe applet script bgsound
  object meta head style link`); everything else passes. This trust model is
  the key simplifier: Markdown's raw-HTML passthrough adds **no new exposure**
  if we pipe its output through the same denylist.
- No Markdown parser or sanitizer exists anywhere; installed Perl stack is
  CGI/HTML::Template/HTML::Parser/HTML::Tree/Text::Iconv (+JSON, HTTP::Tiny).
- No per-article flag column exists, but `bw_xboard_header.category`
  (tinyint, `bx.sql:205`) is **read by no Perl code** — a dormant spare byte.
  Board-level `allow_html` (`bx.sql:125`) is likewise dormant precedent.
- MathJax is already unconditional client-side on board pages
  (`_html_header.tmpl:32`); Prism (with a markdown grammar and fenced-code
  highlighting) already ships in the default skin. Fenced code blocks from
  Markdown will get Prism highlighting **for free**.

### Design (philosophy-fit: server-side, zero new JS, one vendored file)

**D1 — Parser: vendor `Text::Markdown` into `lib/Text/Markdown.pm`.**
Single pure-Perl file (~1.7k lines), no XS, no transitive deps; deploy stays
`git pull` + graceful. Alternative `apt libtext-markdown-perl` rejected only
because vendoring pins the version in-repo and needs no host change. (License:
BSD-style — fine to vendor with header intact.)

**D2 — Opt-in flag: per-article, repurposing `bw_xboard_header.category`**
(0 = legacy bawi markup, 1 = markdown). **Gate G0 PASSED** (owner ran the scan
on prod 2026-07-10: 1,534,413 rows, every one `category=0` — column confirmed
dormant; side-table fallback not needed). Document the repurposing in bx.sql
with a comment.

**D3 — Render branch at read-time** in `format_article` (`Board.pm:1131`):
```
if markdown:  body → Text::Markdown::markdown() → escape_tags denylist
              → strip javascript:/data: hrefs (one regex — cheap hardening
                the md path can have even though the legacy path lacks it)
              → return (NO per-line <br> join, NO make_quote_coloring,
                NO make_hyperlink — markdown owns links/quotes/breaks)
else:         exactly today's pipeline (byte-identical output)
```
Consequences to accept in v1: inside markdown articles, bare attach.cgi image
URLs do NOT auto-embed (author writes `![](url)`), `#N` comment-anchor links
don't linkify, and quote coloring is markdown's `>` blockquote styling
instead. MathJax still works (it scans the final DOM).

**D4 — Scope: articles only.** Comments are `char(200)` — excluded in v1.

**D5 — Write UI:** one checkbox (`Markdown`) as a NEW table row in
`board/skin/default/_write_form.tmpl` (shared by write.tmpl:13 AND
edit.tmpl:13 — one template edit covers both forms), placed directly under
the body-textarea row. Note the form has NO existing options row — this
becomes its first always-visible checkbox (the only current one,
attach-resize, is hidden until a file is attached; 답글허용 does not exist —
comment permissions are per-board in boardcfg, not per-article). CGI side:
`board/write.cgi` + `board/edit.cgi` read the param and pass `-markup`;
`edit.cgi` tparams `markup` from `$$article{category}` to pre-check. Edit
round-trip is lossless (raw source stored). No preview in v1 (no client JS).

**D6 — Performance:** pure-Perl parse of a typical post is ~1–3 ms under
mod_perl (module loaded once); negligible next to DB. If a hot huge article
ever matters, v2 can cache rendered HTML keyed on `bw_xboard_body.modified` —
**only if measured**.
> **Superseded 2026-07-12 (PR #15), measurement taken:** 50 KB bodies bench
> at 0.10–0.92 s per render across shapes (prose 0.11, quotes 0.62, 200×6
> table 0.91; plus a 122 s unclosed-`<pre>` DoS shape fixed in the same PR),
> so the "only if measured" gate was met for large bodies and the owner
> approved shipping the cache as v1: table `bw_xboard_body_html`,
> read-through in `format_article`. Key is `md5(CACHE_VERSION:body)` +
> article_id PK — deliberately NOT the `modified`-timestamp sketch above
> (mtime cannot see pipeline changes; the md5+version key can). Validity
> model lives at `Bawi::Markdown::cache_key`.

**D7 — Search interplay:** FULLTEXT indexes the raw markdown source —
acceptable (syntax characters are noise but content words index fine).

### Phases / task split
| Phase | Owner | Content | Gate |
|---|---|---|---|
| G0 | Claude | prod `category` scan; prod header table size note | all-zero → D2a, else D2b |
| P1 | Codex | vendor Text::Markdown; smoke script (fixtures: headings, fenced code, links, raw HTML, `javascript:` link) | fixtures render; `perl -c` |
| P2 | Codex | flag storage + write/edit checkbox plumbing | flag round-trips write→edit |
| P3 | Codex | `format_article` branch + href-scheme strip | legacy path byte-identical (regression fixture); md path renders |
| P4 | Claude | mirror e2e: md article + legacy article + comment untouched; XSS attempts (`<script>` in md, raw `<iframe>`, `[x](javascript:…)`) all neutralized; Prism highlights fenced block; MathJax unaffected | all pass |
| P5 | Claude | PR, deploy notes (graceful restart; no migration if D2a) | — |

**Owner decisions (grill 2026-07-10) — all resolved, Codex may start at G0:**
(a) articles only (comments excluded, not even as committed v2);
(b) `category` repurpose approved pending the G0 all-zero scan (side table
fallback stands); (c) vendor Text::Markdown into lib/ (no apt dependency);
(d) write UX is a bare checkbox — no preview of any kind in v1.

---

## 4. Career autocomplete (AJAX) burden — assessed, no action needed

The suggest widget is ~40 lines of inline vanilla JS living **only** in
`user/skin/default/career.tmpl` (the career edit page). Nothing is added to
`_html_header.tmpl` or any board/main template — **reading and writing
articles load zero extra JS and make zero extra requests**. The widget itself
is debounced (150 ms timer + stale-response guard), keyboard-navigable, and
the endpoint (`user/organization.cgi`) is an authenticated indexed prefix
query with `LIMIT 10` (alias is the leftmost PK column of `org_alias`).
Worst-case load is a few tiny queries per second while someone types in one
form field. **Verdict: fully consistent with the site philosophy; nothing to
change.** (If org count ever grows 100×, add a 2-char minimum before firing —
one-line change in the widget.)

---

## 5. Parking lot (explicitly deferred, owner-acknowledged)
- **Markdown parser DoS hardening (own PR).** The vendored recursive-descent
  `Text::Markdown` + system `Text::Balanced` are superlinear on several
  attacker-controlled ≤64KB shapes; PR #15 fixed the ones its block-tag guard
  covers but two survive its deep-review (both PRE-EXIST PR #15 and are
  mitigated — not eliminated — by the render cache, which makes cost per-write
  not per-view):
    - **Residual of the `_HashHTMLBlocks` large-tail guard:** a net-unclosed
      block-opener flood whose expensive tail sits in the LAST ≤4096 bytes
      still runs up to 8 O(tail)/O(tail²) extractor attempts. Bounded
      (sub-second at CAP=4096, verified) but not free.
    - **Pipe tables are O(rows×cols):** `_span_md` runs a full
      `Text::Markdown::markdown()` per cell (~1.9 ms/cell), so a 64KB table
      renders in ~10s. No cap that bounds this to <2s leaves a plausible legit
      table (a 100×10 data table is ~1000 cells ≈ 2s) intact, so the fix is
      cheaper per-cell rendering (span-only gamut, output-verified), not a
      row cap — deferred as its own change.
    - **Deep `markdown="1"` nesting + attribute-hostile tail:** a body of
      `<div markdown="1">`×1200 wrapping a ~30KB `<x a=` tail renders ~17s in
      BOTH stock and PR #15 (recursion re-enters `_HashHTMLBlocks` on the
      inner content; the outer guard's precompute adds only ~10%). Another
      concrete shape the systemic budget must cover; not PR-introduced.
    - **Inherent linear floor (~2.5–3.4s per 64KB), guard-independent:** the
      vendored parser costs ~50 µs/paragraph (two `_TokenizeHTML` builds +
      regexes), so ANY ~64KB body is a few seconds in stock — benign
      `"x\n\n"×21000` is 2.6s, `"<\n\n"×21000` is 3.4s, and a balanced-wrapper
      body hiding an inner flood (`<div>×8` … `<pre>×6655` … `</div>×8`) is
      3.2s in BOTH stock and PR #15 (byte-identical). PR #15's guards only
      remove the super-linear blowups; this floor is why "<2s at 64KB" is not
      a general bound and the smoke asserts <2s only on the guarded SKIP
      shapes. The floor needs the systemic budget below or a body-size cap.
  The systemic catch-all remains a per-render wall-clock/work budget
  (`alarm()`/setitimer around the whole `format_article` render) — deferred
  from round 1: SIGALRM under mod_perl interacts with Apache's own timers and
  needs its own PR + soak. Per-construct guards shipping in PR #15: blockquote
  depth clamp, math opener-exclusion, `_del_outside_code` opener-exclusion,
  and the `_HashHTMLBlocks` large-tail + memoized-no-closer + budget guard.
- Korean FULLTEXT quality for search2 (`ft_min_word_len=2` + index rebuild,
  BOOLEAN MODE trailing `*`, LIKE fallback for short keywords) — revisit only
  when search2's load question is settled.
- `myarticle`/`mycomment` 16/page vs boards' 15/page; reverse-numbered
  `[이전]/[다음]` label semantics — behavior-neutral, harmonize on request.
- Legacy match-gating (phone/address/affiliation LIKE clauses run regardless
  of viewer's own sharing; only display is gated) — flagged in PR #8; decide
  whether match itself should be quid-pro-quo like career now is.
- Reflected-param escaping sweep (from deep-review, pre-existing, not
  introduced by any PR): `escapeHTML` the reflected `page`/`bid` params in
  `search2.cgi` / `myarticle.cgi` / `mycomment.cgi` (`url` tparam →
  `_page_nav_special.tmpl` hrefs; search2's `page` sink currently
  unreachable). Systemic pattern; do as one dedicated small PR.
- `make_hyperlink` triplication: signature (`Bawi::User`) and note
  (`Bawi::Main::Note`) copies are `http://`-only (https URLs never embed
  there) and lack jpeg/svg — owner decided to leave untouched; if ever
  revisited, unify all three into the Board one rather than patch piecemeal.
