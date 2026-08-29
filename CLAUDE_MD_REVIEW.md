# CLAUDE.md context-engineering review (local note)

_Local, uncommitted note — not pushed, no GitHub issue filed (production/shared repo). Reviewed 2026-07-26 against Anthropic's [New rules of context engineering for Claude 5](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models). Content is good; this is about **shape**._

## This file is half exemplary, half the anti-pattern.

### The good half (keep — it's textbook Claude-5 style)

The live-state-over-stale-list gotchas are better than most examples in the article itself:
- migrations: *"don't hardcode a list here, it goes stale… `for f in db/2*.sql`"*
- branch: *"Always confirm with `git … branch --show-current` rather than trusting this note"*
- working-tree drift: *"Do not trust a static list here… check live state directly"*
- the production-caution guideline

That pattern — tell Claude *how to find truth* instead of freezing a snapshot — is exactly the judgment-over-rules idea. Keep all of it.

### The trimmable half (inferable from the file tree)

- **`Technology Stack` (L10–16)**, **`Project Structure` (L18–30)**, **`Required Perl Modules` (L70–78)**, **`Architecture Notes` (L79–87)** — Claude reads this straight off the repo. Don't spend tokens on what's inferable from structure; spend them on gotchas (which this file otherwise does well).

## Suggested action

Drop the four structural/stack sections; keep the live-state gotchas + production guideline. ~113 → ~50 lines, and signal-to-noise on the parts that matter goes way up. Production repo — doc-only change, apply via the normal branch/PR flow when convenient.
