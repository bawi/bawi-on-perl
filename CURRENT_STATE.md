# bawi-on-perl — Current State & Maintenance Record

**Date:** 2026-07-06 · **Author:** recon session (Claude) · **Branch:** `maintenance` (off `resp2` HEAD `c81b38a`)

This document is the anchor for the follow-up discussion on (a) merging branches to
`main`/`master` and (b) feature-addition planning. It records the production reality as
found on 2026-07-06 and what the emergency P0 preservation did. All server inspection
was **read-only**; nothing was written to production.

---

## 0. TL;DR

- **Live site** `www.bawi.org` runs from **`/home/bawi/bawi-spring`**, git branch **`resp2`** @ `c81b38a`, on host `orange` (Ubuntu 22.04, Apache 2.4 + mod_perl2, MariaDB 10.6).
- The README's "server ≈ `sync` branch" note is **stale** — the box runs `resp2`.
- Production carried **27 paths of uncommitted drift** (hand-edits + un-integrated features) existing *only* on a single-disk box. **P0 (done this session)** captured the non-secret drift into branch **`resp2-live-snapshot`** (3 commits, pushed to GitHub). Credentials (`conf/*.tmp`) were left on prod and are now gitignored.
- **Deferred:** P1 backups (DB dump, uploads) — *skipped this session by request*. P2 OS patch/reboot — flagged, not done.

## 0b. Update — 2026-07-06 (later): promotion complete + deployed

- **`main` is now the canonical/default branch** (promoted from `resp2`, which was code-identical). **PR #2 merged** (`main` @ `cfc414a`) — carried the `.gitignore` hardening, the 5 live hotfixes, `CLAUDE.md`, and the finalized career spec.
- **Production cut over:** `/home/bawi/bawi-spring` now tracks **`main`** (was `resp2`). Byte-identical served code, **no Apache restart**, verified clean (`git diff origin/main` empty; site returns 200). Prod's pre-cutover untracked `CLAUDE.md`/`CAREER_FEATURE_SPEC.md` backed up to `~/*.pre-cutover.bak` on the host.
- **Branches left in place (no deletions, by request):** `resp2`, `resp2-live-snapshot`, `promote/live-state`, and the `archive/{sync,resp,local,master}` tags. `feature/session-mgmt` (PR #3) remains open (WIP session feature).
- **Career spec finalized** at v3.1 — pulled to the lightweight 학력 grain (flat MyISAM, `enum`, `utf8`); hierarchy / merge / synonyms / per-entry-privacy all deferred to v2.

## 0c. Deferred code bugs (deep-review findings — fix on `test-env`, NOT in the promotion)

Pre-existing **production behavior** the promotion enshrined verbatim. Each needs its own `test-env`-validated PR — not a blind prod edit.

| # | Bug | Sev | Where / fix |
|---|-----|-----|-------------|
| 1 | Poll **`tot` turnout leak** — `get_optset` blanks `pct/width/count` for election polls but not `tot`, which `_pollset.tmpl:35` shows to anyone who has voted / after close | MED | `lib/Bawi/Board.pm` + `_pollset.tmpl` — blank `tot` too, or gate the total row |
| 2 | Poll **fail-open hardcoded ID list** — hidden polls are a hand-typed, accumulate-forever `$pid==` allowlist; the next election leaks live until edited + redeployed | MED | replace with a `hide_results` column on `bw_xboard_poll` |
| 3 | **Phone round-trip corruption** — save skips empty boxes (`edit.cgi:88`), read pop-aligns into `tel4..1` (`User.pm:121`); they agree only when the *sole* empty box is leftmost → a country-code + blank-middle case migrates digits, and a "correcting" re-save silently truncates | MED | pad to 4 fixed dash-joined segments on save, or reject non-4-segment on read |
| 4 | **register.cgi message contradiction** — rejects when `get_ki(recom_id) > recom_ki` but the message says "`recom_ki`기 이상만 추천 가능" (opposite comparison); also in `register.tmpl:100` | MED | fix `이상`↔`이하` after confirming the intended 기 direction |
| 5 | **`im_nate` silent wipe** — input commented out in `edit.tmpl` but `im_nate` still in `edit.cgi:33 @field`, so every profile save overwrites the stored value with `''` | MED | drop `im_nate` from `@field` (mirror how `im_msn` was retired) |
| 6 | `board/test.cgi:23` commented-out crash line (dead — shadowed by `init()`); `has_phone` dead tparam in `edit.tmpl` | LOW | cleanup |

The **career spec** (`CAREER_FEATURE_SPEC.md`, now on `main`) is the design for the next feature — build it on a branch off `test-env`.

---

## 1. Server situation (host `orange`)

| Item | Value | Note |
|---|---|---|
| OS / kernel | Ubuntu 22.04.5 LTS / `5.15.0-88` | kernel is old (running since boot) |
| **Uptime** | **970 days** | never rebooted since ~Nov 2023 |
| **Pending apt updates** | **88** | `*** System restart required ***` is set |
| Disk | `/dev/sda1` 234G, **68% used**, 72G free | single disk; no second/backup mount seen |
| Web | Apache **2.4.52** + `libapache2-mod-perl2 2.0.12` | binary rebuilt 2026-05-05 (needs restart to load) |
| Perl | 5.34.0 (system) | |
| DB | MariaDB **10.6.23**, `127.0.0.1:3306` only | DB name `bawi`; not network-exposed (good) |
| Ports | 80/443 world, 3306 localhost | |
| Locale | Korean (ko_KR) | |

**Risk flags:** 970-day uptime + 88 unpatched updates + reboot-required on a public host is
the top ops exposure, *but* rebooting a 2.7-year-old box is itself risky (untested boot path).
See §6 P2.

**Other tenants on the box** (out of scope, noted for awareness): `aragorn` runs
`main.bawi.org` + wisebot/arxiv/bot-demo; `linusben` has `bawi-auth`; `woosong`, `mojo` have
repos. `~/rsync.sh` pulls from an old host `cafe24.bawi.org` (legacy deploy/backup relation).

---

## 2. Serving repo & Apache wiring

- **Repo:** `/home/bawi/bawi-spring` → remote `github.com/bawi/bawi-on-perl`, branch **`resp2`** @ `c81b38a`, **0 ahead / 0 behind origin** (committed history fully pushed & safe).
- **vhost:** `sites-enabled/100-bawi.conf → sites-available/bawi-spring`.
  - `DocumentRoot /home/bawi/bawi-spring/main`; `ServerName www.bawi.org`, aliases `bawi.org m.bawi.org old.bawi.org`.
  - HTTP→HTTPS redirect; SSL vhost on :443.
  - `PerlPostConfigRequire /home/bawi/bawi-spring/apache2/startup.pl` (mod_perl bootstrap).
  - `ModPerl::Registry` handles `*.cgi` under `board/` and `reg/`; ExecCGI elsewhere.
  - Path aliases: `/board /user /reg /admin /x /xboard` → repo dirs; `/event` → `~/pay-it-forward`.
  - `<Location /server-status>` is `Allow from all` — **minor exposure**, worth restricting later.
- **cron (user `bawi`):** `bin/update_load_graph` (1 min); 3× `mysql -u bawi bawi < main/sql/update_*_stat.sql` (3 min / daily). These read from the repo path — the deploy tree is load-bearing for cron too.

---

## 3. Branch topology (decision surface for "merge to main")

| Branch | Head | Date | vs resp2 | Meaning |
|---|---|---|---|---|
| **`resp2`** | `c81b38a` | 2025-07 | — | **LIVE / deployed.** The real code. |
| `resp2-live-snapshot` | `a39c847` | 2026-07 (new) | +3 | resp2 + preserved prod drift (this session) |
| `master` | `1045274` | 2022-09 | +5 / −35 | **default branch**, but its 5-commit lead is **only merge/README/INSTALLATION doc commits — no functional code** |
| `sync` | `ab707fa` | 2022-09 | 0 not in resp2 | **fully absorbed into resp2** → redundant |
| `resp` | `22d8da6` | 2022-09 | 3 not in resp2 | near-absorbed; 3 stray commits |
| `local` | `b808b88` | 2017-12 | 13 not in resp2 | 2017 dev-setup branch (holds real INSTALLATION.md); stale |

**Key fact:** the 5 commits `master` has over `resp2` are:
`Merge PR#1 from sync`, `Merge commit 355d590`, `Merge branch 'sync'`, `Dummy INSTALLATION.md`,
`Update README`. All doc/merge noise. **`resp2` is strictly ahead of `master` in actual code.**

→ Making `resp2` the mainline is code-safe; only the README/INSTALLATION docs need reconciling.
Candidate strategies to weigh in the discussion are in §7.

---

## 4. Uncommitted drift inventory (as found on prod, 2026-07-06)

**27 paths total.** Preservation status after P0 in brackets.

### 4a. Modified tracked files — 5 (+32 / −14) — live hotfixes [PRESERVED → `resp2-live-snapshot`]
| File | Change | Why it matters |
|---|---|---|
| `lib/Bawi/Board.pm` | hide poll %/counts for election poll IDs 1427/9696/9698/9804/9857/9884/9886 | **vote-privacy** logic for alumni-president elections |
| `reg/register.cgi` | `$recom_ki` 36 → 37 | current recommender cohort (bumped per intake) |
| `user/skin/default/edit.tmpl` | phone-form rework; drop Nate/MSN messenger rows | UI |
| `user/skin/default/profile.tmpl` | comment out Nate messenger row | UI (pairs with edit.tmpl) |
| `board/test.cgi` | disable mobile-cookie `tparam` line | minor |

### 4b. Untracked features / docs — 15 [PRESERVED → `resp2-live-snapshot`]
- **beta read view (2020):** `board/read_beta.cgi`, `skin/default/read_beta.tmpl`, `script_beta.js`, `_comment_beta.tmpl`, `_html_header_beta.tmpl`
- **session mgmt (2018):** `board/mysessions.cgi`, `remove_session.cgi`, `skin/default/mysessions.tmpl`
- **dark mode stub (2021):** `board/skin/default/dark_style9.css`
- **register variant (2023):** `reg/register.cgi.pinadd`
- **misc/legacy:** `admin/reg2.sql`, `admin/regtemp.sql`, `board/attach_deprecated.cgi`
- **planning docs (2025, from a prior on-server Claude session):** `CAREER_FEATURE_SPEC.md`, `CLAUDE.md`

### 4c. Left on prod (NOT pulled) [gitignored or noted]
- 🔴 `conf/board.tmp`, `conf/main.tmp`, `conf/user.tmp` — **live DB credentials.** Now covered by `.gitignore` (`conf/*.tmp`). Stay on prod only.
- `main/BingSiteAuth.xml`, `main/google*.html` — search-console verification tokens (deploy artifacts). Gitignored.
- `maint` (8-byte stray marker). Gitignored.

---

## 5. What P0 did this session (emergency preservation)

Executed entirely in the **local clone** — **zero writes to production**. Drift was pulled via
`rsync` over the already-authenticated ControlMaster SSH (no credentials pulled).

Branch **`resp2-live-snapshot`** (pushed to `origin`), 3 commits:
1. `d7090e9` — harden `.gitignore` (`conf/*.tmp` + deploy artifacts) so secrets can't be staged.
2. `2311f6a` — snapshot the 5 tracked hotfixes.
3. `a39c847` — snapshot the 15 untracked features/docs.

**Result:** prod-only work is now durable on GitHub (off the single disk). Reconciliation into
`resp2`/mainline is deliberately deferred to the discussion — this branch is preservation, not a merge.

---

## 6. Deferred (NOT done this session)

- **P1 — backups (skipped by request):** MariaDB `bawi` has **no dump cron**; `xboard_attach/` +
  `photo_attach/` (user uploads, **777**, not in git) have no off-box copy. This remains the
  largest data-loss exposure. Recommended next: nightly `mysqldump` + uploads rsync to an
  off-box target (O2 standby or cafe24), and tighten 777 perms.
- **P2 — OS patch/reboot:** 88 updates + reboot-required. Do **after** P1, as a *rehearsed*
  window: verify Apache/MariaDB are `enable`d for auto-start, secure out-of-band console, then
  `apt upgrade` + reboot. Also a graceful Apache restart to load the 2026-05 patched binary.

---

## 7. Open decisions for the next session

### A. Merge branches to `main`/`master`
Given `resp2` is strictly ahead of `master` in code (§3), options:
1. **Promote `resp2` → mainline.** Reconcile snapshot hotfixes into `resp2`, then make `resp2`
   the default branch (or fast-forward/merge into `master`, hand-resolving the README/INSTALLATION docs). Delete `sync` (absorbed); archive `resp`/`local`.
2. **Merge `resp2-live-snapshot` → `resp2` first**, curating which untracked items are real
   (e.g. keep beta/session/dark-mode if wanted; drop `attach_deprecated`, `regtemp`), then A.
3. Rename default `master` → `main` as part of the cleanup (GitHub side).
- **To investigate:** the 3 stray `resp` commits and 13 `local` commits — confirm nothing worth keeping before archiving.

### B. Feature-addition planning (inputs already on hand)
- `CAREER_FEATURE_SPEC.md` (15 KB spec, 2025) — read and scope.
- Latent features found in drift: **beta read view**, **dark mode**, **session management** —
  decide integrate vs. drop.
- Modernization (mod_perl→PSGI, CGI framework, etc.) is **aspirational** — a separate track,
  not part of maintenance.

---

## Appendix — access / relay notes
- Local clone: `~/repos/bawi-on-perl` (on `resp2`); this worktree: `~/repos/bawi-on-perl-wt-maintenance` (on `maintenance`).
- Relay host **`bawi`** (see remote-relay skill): www.bawi.org, user `bawi`, password auth (no 2FA), `REQUIRES_2FA=true`, `ALLOW_INFLOW=false` (recon posture). ControlMaster persists the manual password for the session.
- **Relay caveat:** `relay_run` pane-scrape is unreliable over the nested-tmux + trans-Pacific link; use **`relay_capture`** / direct `ssh bawi` over the ControlMaster instead.
