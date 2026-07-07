# Career feature — implementation spec

Career (job) history for users: company, position, period. Mirrors the
existing **degree** feature (`bw_user_degree` / `user/degree.cgi` /
`user/skin/default/degree.tmpl`) as closely as possible — same idioms, same
naming, same validation, same template style. Where this spec is silent,
**copy the degree implementation's behavior exactly**. Do not introduce new
abstractions, helpers, frameworks, or dependencies; this codebase is
deliberately lightweight and the diff must be too.

Precedence: this spec > mirroring degree > anything else.

## Revisions (2026-07-06, post-review — these supersede the prose below)

1. **No `content` / 업무 내용 field.** Dropped as unnecessary (position already
   conveys the role). Remove it from the table, all `Bawi::User` career subs,
   `career.cgi` (params + escape), and `career.tmpl`.
2. **Dates are optional; only company + position are required.** The save guard
   is `if ($uid && $company && $position)`. `$s_date`/`$e_date` default to the
   `'1001-01-01'` sentinel when a period is left at the "현재" default (the
   dropdown's first option), so a company+position-only entry saves instead of
   being silently discarded. `get_career` blanks the start-date sentinel
   (`s/1001-01//`) so such rows render `[~현재]`.

## Data model

New file `db/20260706_add_user_career.sql` (single statement, no trailing
semicolon issues — match the style of the existing `db/2*.sql` files):

```sql
CREATE TABLE `bw_user_career` (
  `career_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint(8) unsigned NOT NULL DEFAULT 0,
  `company` varchar(255) NOT NULL DEFAULT '',
  `position` varchar(255) NOT NULL DEFAULT '',
  `start_date` date NOT NULL DEFAULT '1001-01-01',
  `end_date` date NOT NULL DEFAULT '1001-01-01',
  PRIMARY KEY (`career_id`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci
```

Notes:
- No `status` column and no lookup table: `end_date = '1001-01-01'` already
  means "현재" (currently employed), same sentinel the degree feature uses.
  Company is free text (there is no `companies` lookup table and we are not
  adding one).

## lib/Bawi/User.pm

Add these subs, each placed next to and mirroring its degree twin
(`get_degree`, `has_degree`, `degree_set`, `degree`, `update_degree`,
`add_degree`, `del_degree`):

- `get_career($uid)` — like `get_degree` but no `schools` join. Select
  `career_id, company, position, content, start_date, end_date` with
  `date_format(..., "%Y-%m")` on both dates; `s/1001-01/현재/` on end_date;
  sort like get_degree (rows with end "현재" last, others by end_date asc).
  No type_brief/status_brief mapping (careers have neither).
- `has_career($uid)` — mirror `has_degree` (count rows in `bw_user_career`,
  same `$max_ki - $ki < 5` old-timer bypass).
- `career_set($uid)` — mirror `degree_set`: first element is the blank form
  (only `start_year/end_year/start_month/end_month` lists — no school_list),
  then one element per existing row with `-current` selections and
  `career_id, company, position, content`.
- `career($uid, $career_id)`, `update_career(...)`, `add_career(...)`,
  `del_career($uid, $career_id)` — mirror the degree equivalents with
  columns `(career_id, uid, company, position, content, start_date, end_date)`.
- In the existing `profile` sub (the one that sets `$$p{degree} =
  $self->get_degree($uid);`), add `$$p{career} = $self->get_career($uid);`
  directly after the degree line.

## user/career.cgi (new, chmod 755 — mod_perl 403s without the exec bit)

Clone of `user/degree.cgi` with the school/advisor logic removed:

- Template `career.tmpl`, `menu_profile=>1`, same auth gate, same
  id/name/user_url/note_url tparams.
- Params: `action, cid, company, position, content, start_year, start_month,
  end_year, end_month` (`cid` = career_id, plays the role degree.cgi's `did`
  plays).
- Keep the date validation block byte-for-byte (end before start clears the
  end fields; `1001` sentinel handling; `$s_date`/`$e_date` construction).
- Save when `$uid && $company && $position && $s_date && $e_date`;
  `escapeHTML` company, position, and content before writing (degree.cgi
  escapes its free-text fields the same way). No advisor-title stripping.
  `cid` present → `update_career`, else `add_career`; call
  `$user->modified($uid)` after either, exactly like degree.cgi.
- `action=del&cid=N` → `del_career`, with the same `modified` call guard.
- Final tparams: `ki`, `careers => get_career`, `career_set => career_set`.

## user/skin/default/career.tmpl (new)

Clone of `degree.tmpl`:

- Same header block (photo, ki link, name, the [개인정보 변경 | …] links).
- Listing row titled `입력된 경력`:
  `<tmpl_var company>, <tmpl_var position> [<tmpl_var start_date>~<tmpl_var end_date>]
  <a href="career.cgi?action=del&cid=<tmpl_var career_id>">[삭제]</a>`
  with the same `<tmpl_unless __last__><br></tmpl_unless>` separator.
- Form loop over `career_set` posting to `career.cgi` (hidden `cid` when
  editing): rows 회사명 (text input `company`), 직위/직책 (text input
  `position`), 업무 내용 (text input `content`) — all
  maxlength 255, same styling as degree.tmpl's text inputs — and 기간 (the
  four year/month selects, same loops as degree.tmpl, **no status select**).
  Submit button: 추가 on first loop iteration, 변경 otherwise (same
  `__first__` trick).

## user/skin/default/profile.tmpl

- Change the degree row label `학위/경력` → `학위` (career now has its own row).
- After the closing `</tmpl_if>` of the degree block, add a career block with
  the same structure (including the `_reciprocal.tmpl` fallback):

```
        <tmpl_if career>
<tr>
    <td class="lhead" nowrap>경력</td>
    <td class="iteml">
            <tmpl_if has_career>
                <tmpl_loop career>
        <tmpl_var company>, <tmpl_var position> [<tmpl_var start_date>~<tmpl_var end_date>]<tmpl_unless __last__><br></tmpl_unless>
                </tmpl_loop>
            <tmpl_else>
            <tmpl_include _reciprocal.tmpl>
            </tmpl_if>
    </td>
</tr>
        </tmpl_if>
```

## user/profile.cgi

Next to the existing degree lines add:
- `$$p{has_career} = $user->has_career($auth->uid);` (with the other
  `has_*` lines)
- `$$p{career} = $user->get_career($uid);` (next to `$$p{degree} = ...`)

## user/skin/default/edit.tmpl

- Change the row label `학위/경력` → `학위`.
- After that row's `</tr>`, add a career row mirroring it (data comes from
  the `profile` sub via `$$p{career}`):

```
<tr>
    <td class="lhead" nowrap>경력</td>
    <td class="iteml">
        <tmpl_if career>
            <tmpl_loop career>
        <tmpl_var company>, <tmpl_var position> [<tmpl_var start_date>~<tmpl_var end_date>]<tmpl_unless __last__><br></tmpl_unless>
            </tmpl_loop>
        </tmpl_if>
    [<a href="career.cgi">추가/변경</a>]
    </td>
</tr>
```

First verify (grep) that edit.cgi's template data really comes from
`Bawi::User::profile` — if it does not, wire `career` the same way `degree`
reaches edit.tmpl.

## Out of scope — do NOT touch

- `user/company.cgi` (unrelated stub), `seed/`, `docker/`, `conf/`,
  `docker-compose.yml`, `PLAN.md`, any other board/main code.
- No git operations. No docker build/up/down. Leave all changes uncommitted.

## Verification (must all pass before you finish; run from the repo root)

The Docker test stack is already running (web container live-mounts this
tree at `/home/bawi/bawi-spring`).

1. Syntax: `docker compose exec -T web bash -c 'cd /home/bawi/bawi-spring/user && perl -c career.cgi && perl -c profile.cgi && cd ../lib && perl -I. -c Bawi/User.pm'` → all "syntax OK".
2. Migration: `docker compose exec -T db bash /docker-entrypoint-initdb.d/20-apply-migrations.sh` → reports `20260706_add_user_career.sql` applied; then
   `docker compose exec -T db mysql -ubawi_test -pbawi-local-test-pw bawi -e 'describe bw_user_career'` succeeds.
3. Reload mod_perl so the new/edited `.pm` is picked up:
   `docker compose restart web` (wait ~5s for it to come back).
4. HTTP smoke (the stack serves on localhost:8080; test login below is
   synthetic seed data, password documented in the repo's PLAN.md):
   - `curl -si -c /tmp/career-cj.txt -d 'id=testuser02&passwd=test1234' http://localhost:8080/main/login.cgi` → 302 + `bawi_session` cookie.
   - `curl -si -b /tmp/career-cj.txt http://localhost:8080/user/career.cgi` → 200, page contains `입력된 경력` form markup (`name="company"`).
   - `curl -si -b /tmp/career-cj.txt -d 'company=가상전자&position=선임연구원&content=테스트&start_year=2020&start_month=03&end_year=1001&end_month=00' http://localhost:8080/user/career.cgi` → 200 and the response lists `가상전자, 선임연구원 [2020-03~현재]`.
   - `curl -si -b /tmp/career-cj.txt http://localhost:8080/user/profile.cgi` → 200 and contains the `경력` row with `가상전자`.
   - Delete round-trip: extract the `cid` from the career.cgi page, `curl -si -b /tmp/career-cj.txt 'http://localhost:8080/user/career.cgi?action=del&cid=<cid>'` → 200 and the entry is gone (and gone from profile.cgi too).
5. `docker compose logs --tail=50 web` shows no new Perl warnings/errors from these requests (ignore pre-existing noise).
