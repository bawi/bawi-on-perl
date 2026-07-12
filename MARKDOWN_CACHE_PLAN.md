# Markdown render caching — design proposal (DRAFT)

Follow-up to PR #14 (markdown mode) and the Text::Markdown perf fix. **This
PR is a draft to agree the approach — the implementation in it is the
minimal option #1, wired up so the review has something concrete to run.**

## Problem

`category==1` bodies are rendered by `Bawi::Markdown::render()` at **read
time, uncached, once per article**, and thread / new-article views render up
to ~15 articles per page (`board/read.cgi`, `read_scrap.cgi`). Even after the
`Text::Markdown` O(n²) fix, a realistic 50 KB body still costs ~0.2–0.4 s per
render, `_pipe_tables`/`_span_md` call `Text::Markdown::markdown()` once per
cell, and a couple of residual shapes (an unclosed raw `<pre>` + long body)
stay ~0.4 s. All of it recomputes on every view of the same unchanged article.

## Goal

Make render cost **~one-time per body**, not once per view.

## What to cache, and the key

Cache the output of **`render()`** — the expensive, deterministic stage.
Deliberately **not** the `escape_tags` denylist + `javascript:` href strip
that `format_article` applies afterward: those are cheap and depend on the
**per-board** `escaped_tags` column, so keeping them outside the cache means a
board changing its denylist takes effect immediately instead of being frozen
into a cache entry.

`render()` is pure in `($body, $uniq=article_id)`, so:

```
key = CACHE_VERSION : article_id : md5(body-bytes)
```

- A **body edit** changes the md5 → automatic invalidation (the stale entry
  just lingers until evicted; it is never served for the new body).
- `article_id` is in the key because it namespaces footnote anchors
  (`fn-<id>-<n>`), so two articles with identical bodies must not share a
  render.
- A **pipeline change** (module logic) is invalidated by bumping
  `$Bawi::Markdown::CACHE_VERSION`.

## Options (ranked; this draft implements #1)

1. **Per-worker in-memory `%cache`** — *implemented in this draft.* A file-
   lexical hash in `Bawi::Markdown`, persistent across requests within a
   mod_perl worker. Zero infra. Trade-offs: not shared across workers (N
   workers hold up to N copies of a hot entry), lost on graceful restart, and
   eviction here is a **coarse flush-when-full** (`CACHE_MAX=500` entries,
   then clear) — no LRU yet.
2. **Shared file cache under `BAWI_DATA_HOME`** — survives restart, shared by
   all workers; needs a path scheme, atomic writes, and a cleanup/eviction
   policy (size or age). More moving parts.
3. **`rendered_body` column + render-at-write** — the fullest fix: render once
   on save, read is a plain column fetch. Needs a migration, a write-path
   change in `write.cgi`/`edit.cgi`, and a re-render sweep whenever
   `CACHE_VERSION` bumps (or a lazy "render if column null/stale" read path).

## Open questions for review

- **Which store?** #1 is enough to kill the per-view recompute on hot threads
  with no infra; #3 is the "correct" end state but is the biggest change.
- **Eviction:** flush-when-full (current) vs a small LRU vs a TTL. Flush is
  crude but bounded and simple; is per-worker memory (~500 × a few KB ≈ low
  single-digit MB) fine as-is?
- **Cache scope:** just `render()` (this proposal) vs the whole
  `format_article` category==1 output (would also key on `escaped_tags`).
- **Metrics:** worth a hit/miss counter to size `CACHE_MAX` from real data?

## What this draft changes

- `lib/Bawi/Markdown.pm`: adds `render_cached($body, $uniq)` (option #1) next
  to the unchanged, still-pure `render()`.
- `lib/Bawi/Board.pm`: `format_article` calls `render_cached` instead of
  `render` (one line).
- `board/script/markdown_smoke.pl`: asserts a cache hit returns byte-identical
  output to a direct `render()`, and that a `CACHE_VERSION` bump re-renders.

No migration, no new dependency (`Digest::MD5` is core). Deploy is the usual
`git pull` + graceful restart; the per-worker cache simply starts cold.
