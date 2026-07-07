# Career feature — spec & notes

Job-history for user profiles (company, position, optional period), mirroring
the existing **degree** feature (`bw_user_degree` / `user/degree.cgi` /
`user/skin/default/degree.tmpl`). Same idioms; no new abstractions or deps.

## Data model — `db/20260706_add_user_career.sql`

`bw_user_career`: `career_id` (PK, auto-inc), `uid`, `company` varchar(255),
`position` varchar(255), `start_date` date, `end_date` date. MyISAM, utf8mb3
(matches the sibling tables; Korean names fine, emoji not — a site-wide limit).
No `status` column and no company lookup table: the `1001-01-01` date sentinel
already encodes "현재" (present / unknown), the same sentinel degree uses.

## Code

- `lib/Bawi/User.pm` — `get_career`, `has_career`, `career_set`, `add_career`,
  `update_career`, `del_career`, each mirroring its degree twin; plus one line
  in `get_user` (`$$p{career} = $self->get_career($uid)`) — that is how career
  reaches **edit.cgi** (the `profile` tparam). `profile.cgi` wires career
  itself (`$$p{career}` / `$$p{has_career}`), it does not go through `get_user`.
  - `update_career` uses `UPDATE ... WHERE career_id=? AND uid=?` (not
    `REPLACE`), and `del_career` is uid-scoped — a forged `career_id` can't
    touch another user's row.
- `user/career.cgi` — add / edit / delete page (mode 755, or mod_perl 403s).
  Only `company` and `position` are required; both are trimmed and
  length-checked (blank/whitespace-only is rejected with a warning; a literal
  `"0"` is accepted). A failed DB write surfaces an error, not a silent success.
- `user/skin/default/career.tmpl` — list + form; missing-field warning via the
  standard `$ui->msg` / `<tmpl_if msg>` banner (same idiom as passwd/edsig).
- Profile + edit pages show a 경력 row (the old combined 학위/경력 label is
  split into 학위 and 경력).

### Optional-date model (differs from degree, which requires dates)

Dates are optional. In `career.cgi` the "현재" sentinels (year `1001`, month
`00`) are normalized so nothing is silently dropped:

- a real year with its month left at 현재 keeps the year (never collapsed to
  "no date"), defaulting the month to **January for a start** and **December
  for an end** — so "ended in YYYY" is never read as before a same-year start;
- a year left at 현재 clears its month → the date becomes the `1001-01-01`
  sentinel, rendered `현재` (end) or blank (start → `[~end]`);
- an unknown (blank) start never invalidates a known end; only a real end that
  precedes a real start is rejected — and that is **warned**, not dropped
  silently (the other fields still save).

`career_set` shows a stored sentinel date as 현재/현재 in the edit form so a
re-save round-trips cleanly.

## Verification (localhost:8080 test env; login `testuser02` / `test1234`)

The Docker stack live-mounts this tree; restart web after editing `*.pm`.
Each curl asserts a behavior above — all must hold:

1. `describe bw_user_career` → 6 columns, no `content` / `status`.
2. Save `company`+`position` only (no dates) → row renders `[~현재]`.
3. Save a real **end** (e.g. 2018-06) with start left at 현재 → the end is
   **kept** (`[~2018-06]`), not discarded.
4. Save a real start **year** with its month at 현재 → the year is **kept**
   (`[2020-01~...]`); a real end year with month at 현재 stores `YYYY-12`
   (never `YYYY-00`, and not wrongly cleared) — e.g. start 2015-03 + end year
   2015 month 현재 → `[2015-03~2015-12]`, the end is not silently lost.
5. Save with `position` blank (or whitespace-only) → yellow
   `직위/직책 … 저장됩니다` banner, nothing saved. A `company` of `"0"` saves.
   A real end genuinely before a real start → the end date is dropped **with a
   warning**, not silently.
6. As `testuser02`, POST an edit with a forged `cid` (a row owned by another
   user) → that user's row is unchanged (0 rows updated).
7. Add → edit → delete round-trips on the owner's own rows; profile/edit show
   the 경력 row.
