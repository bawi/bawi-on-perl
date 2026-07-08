# Career Feature Implementation Specification — v3.2

**Status:** supersedes v3.1. This is the single source of truth (SSOT) for the
career (경력) feature. Production branch is **`main`**.

**What v3.2 changes vs v3.1** (decisions from the 2026-07-07/08 design review):
- Organizations are a **lookup that users grow on the fly** (type-ahead
  suggests existing ones; a new name is created on save, **usable
  immediately**) — *not* free text (the PR#4 prototype) and *not* an
  approval-gated queue (v3.1).
- **No per-submission approval.** Instead, an **admin maintenance tool** merges
  duplicates and manages aliases occasionally (not a queue).
- **Conservative aliasing**, **dual/concurrent positions**, **`end_date IS NULL`
  = ongoing**, and an **org seed combed from real affiliation data**.

---

## 1. Overview

Split the legacy combined 학위/경력 system: 학위 stays on `bw_user_degree` +
`schools`; **경력 becomes its own feature** with an `organizations` lookup.
Organizations are volatile and multilingual (unlike the stable `schools` list),
so the lookup is deliberately lighter: no rigid pre-curation, no approval gate —
it grows from what users type, with an admin tool to tidy (merge/alias) when
convenient. Keeps the "학력 grain": flat MyISAM, no FKs, direct DBI, compact code.

## 2. Design decisions (the deltas that define v3.2)

1. **Org identity = a lookup** (`organizations` + `org_alias`), created on the
   fly by users. Type-ahead suggests from existing orgs and their aliases.
2. **No approval workflow.** New orgs are live immediately. An **admin
   merge/alias tool** (occasional maintenance) is where duplicates get merged
   and cross-script aliases (Samsung↔삼성) get declared.
3. **Conservative aliasing** — only *true synonyms* merge. Distinct sub-entities
   stay separate (삼성전자 ≠ Samsung Research ≠ SAIT). University *departments*
   fold to the university (the real employer); hospitals stay separate from
   their university.
4. **Seed from real data** — combed from `bw_user_basic.affiliation`
   (de-identified aggregate). Generated + reviewed + loaded **locally; NOT
   committed** to this public repo (privacy). ~235 orgs.
5. **Dual / concurrent positions** — multiple career rows per user, overlapping
   dates allowed, **multiple ongoing (NULL end_date) allowed**. No non-overlap
   constraint (a professor who also advises a startup = two rows).
6. **`type` enum** — employment / internship / volunteer / research / military /
   other (military service 군복무 matters for this population).
7. **`end_date IS NULL` = ongoing; `start_date IS NULL` = unknown.** No
   `1001-01-01` sentinel (retires the special-case date code — and the bugs a
   two-round review found in the PR#4 prototype). Sort:
   `ORDER BY (end_date IS NULL) DESC, end_date DESC`.
8. **Reuse the hardened bits from the PR#4 prototype**: ownership-scoped writes
   (`WHERE uid`), the missing-field `$ui->msg` warning, trim + length-checked
   inputs.

## 3. Schema

`db/20260708_create_career.sql` (additive after one drop; rollback = `DROP` x3 +
git revert):

```sql
-- The PR#4-era table (created 2026-07-06 on prod, never went live, no real
-- data) is a different shape — drop it before creating the v3.2 tables.
DROP TABLE IF EXISTS bw_user_career;

CREATE TABLE organizations (
  org_id       int unsigned NOT NULL AUTO_INCREMENT,
  name         varchar(128) NOT NULL DEFAULT '',   -- canonical display name
  created_by   mediumint unsigned NOT NULL DEFAULT 0,
  created_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (org_id),
  KEY name (name)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;   -- utf8_general_ci: case-insensitive alias search

CREATE TABLE org_alias (
  alias  varchar(128) NOT NULL DEFAULT '',   -- every searchable name, incl. the canonical
  org_id int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (alias, org_id),
  KEY org_id (org_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE bw_user_career (
  career_id       mediumint unsigned NOT NULL AUTO_INCREMENT,
  uid             mediumint unsigned NOT NULL DEFAULT 0,
  type            enum('employment','internship','volunteer','research','military','other')
                    NOT NULL DEFAULT 'employment',
  organization_id int unsigned NOT NULL DEFAULT 0,
  position        varchar(255) NOT NULL DEFAULT '',
  start_date      date DEFAULT NULL,   -- NULL = unknown
  end_date        date DEFAULT NULL,   -- NULL = ongoing (multiple NULLs per uid allowed)
  PRIMARY KEY (career_id),
  KEY uid (uid),
  KEY organization_id (organization_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
```

No `department`/`description` (position suffices; add later if wanted). No FKs
(house style; a hidden org's careers vanish via the inner join, exactly as a
deleted school hides degrees today). No non-overlap constraint (dual positions).

## 4. Behavior

### 4.1 User — `user/career.cgi` + `user/skin/default/career.tmpl`
- CRUD modeled on `degree.cgi`, but the org field is a **type-ahead text input +
  hidden `organization_id`**.
- **Type-ahead:** on keyup, hit the suggest endpoint; show a dropdown of
  matching orgs; picking one fills the visible name and the hidden `org_id`.
- **New org:** a typed name with no pick → on save, `resolve_or_create_org`
  finds an exact alias match or creates `organizations` + `org_alias` rows,
  returns the id. No approval — live immediately.
- **Ownership:** `update_career` / `del_career` scoped `WHERE ... AND uid=?`
  (from the PR#4 fixes; a forged `career_id` hits 0 rows).
- **Missing-field warning** via `$ui->msg` / `<tmpl_if msg>` yellow banner (same
  idiom as `passwd.tmpl`/`edsig.tmpl`). Inputs trimmed + length-checked.
- **Dual positions:** nothing prevents multiple / overlapping / concurrent
  (multiple NULL end_date) entries.
- **Sort:** `ORDER BY (end_date IS NULL) DESC, end_date DESC` — current first.

### 4.2 Suggest endpoint — `user/organization.cgi?q=<typed>` (or `career.cgi?suggest=`)
```sql
SELECT DISTINCT o.org_id, o.name
FROM org_alias a JOIN organizations o ON a.org_id = o.org_id
WHERE a.alias LIKE ?           -- '<q>%'  (utf8_general_ci → case-insensitive)
ORDER BY o.name LIMIT 10;
```
Returns a small JSON (or newline) list. Cross-script matching happens **only via
aliases** (utf8 folds ASCII case, not scripts) — hence the seed + admin tool.

### 4.3 Type-ahead widget
~40 lines of **dependency-free vanilla JS** (no jQuery; Prototype.js is loaded
on some pages but a self-contained widget is lighter and page-independent).
Lives in `career.tmpl` (or the user skin's inline `<script>` block). XHR to the
suggest endpoint, render/keyboard-navigate a dropdown, on select set input +
hidden id. Degrade gracefully: if JS is off, the text field still accepts a
typed name (create-on-save still works).

### 4.4 Admin — `admin/organizations.cgi` + `admin/skin/default/organizations.tmpl`
`is_admin`-gated (`Bawi::Auth::is_admin`), cloned from `admin/index.cgi`, linked
in `admin/_menu.tmpl`. **Maintenance, not a queue:**
- **List** orgs (name, usage count, aliases).
- **Merge** two orgs: repoint `bw_user_career.organization_id` dupe→canonical,
  move `org_alias` rows, delete the dupe. (Where Samsung↔삼성 gets linked.)
- **Aliases:** add / edit / delete an org's aliases.

## 5. `lib/Bawi/User.pm` methods (4-line direct-DBI style, like `add_degree`)

```
get_career($uid)              # rows joined to organizations.name, ongoing-first
add_career(@)  update_career($@ WHERE uid)  del_career($$ WHERE uid)  career_set($)
org_suggest($q)               # alias-prefix search (the endpoint's query)
resolve_or_create_org($name, $uid)   # exact-alias match, else create org+alias
org_list()  org_merge($from,$to)  org_add_alias($org,$alias)  org_del_alias($org,$alias)   # admin
```

## 6. Organization seed (from real affiliation data — local, NOT committed)

- **Source:** `bw_user_basic.affiliation`, extracted **de-identified &
  aggregated** (`SELECT affiliation, COUNT(*) GROUP BY affiliation`, no `uid`).
  Privacy: only an org-level aggregate is produced; the raw extract stays on the
  local machine; **the seed data is not committed to this public repo** — it is
  loaded into the DB directly (local test env, then prod).
- **Conservative combing rules:**
  - Drop noise (`UNKNOWN`/`없음`/`무직`/`재학생`/`.`…) and the **alma mater**
    (서울과학고 family incl. the nickname 설곽) — not career orgs.
  - Strip trailing personal titles/grades **as whole tokens** (교수, 연구원-as-
    title, N학년) — never inside a compound name (`한국원자력연구원`,
    `삼성전자 반도체연구소` survive intact).
  - **Fold university departments** to the university (`서울대학교 수리과학부`
    → `서울대학교`); **hospitals stay separate** (`서울대학교병원` ≠ `서울대학교`).
  - Merge **only true synonyms** as aliases: `삼성전자`←Samsung Electronics;
    `KAIST`←카이스트; `MIT`←Massachusetts Institute of Technology;
    `Stanford University`←Stanford; `Apple`←Apple Inc.;
    `서울대학교`←Seoul National University; `서울대학교병원`←서울대병원.
    Distinct sub-entities stay separate (Samsung Research, SAIT, 삼성전자
    divisions, SK hynix/Innovation/Telecom, LG전자/LG화학 — each its own org).
  - Threshold **n≥2** (common orgs). The n=1 long tail (individual employers,
    also the potentially-identifying singletons) is left to grow organically via
    type-ahead, not seeded.
- **Result:** ~235 orgs covering ~1,300 profiles. A **draft for human review**
  before load; the admin tool refines the rest. (Combing scripts live in the
  session scratchpad; they read the local extract, so they are not in the repo.)

## 7. Development & deployment

### 7.1 Where to build (resolved)
- Build on **`career-v3.2`** (this branch, off **`main`** = current production
  code). **Not** `test-env` (an older snapshot of the main line + Docker,
  missing `main`'s recent hotfixes) and **not** `master` (abandoned, 2022).
- For local testing, bring the **Docker harness** onto the dev worktree by
  cherry-picking test-env's Docker commit **`2536177`** (`docker-compose.yml`,
  `docker/`, `seed/`, `conf/`, `PLAN.md`). It mirrors prod (Apache 2.4 +
  mod_perl2 + Perl 5.34 + MariaDB 10.6), mounts the repo at
  `/home/bawi/bawi-spring`, and is **local-only (fake creds; never pushed)**.
  The guarded migration runner applies `db/*.sql`, so the v3.2 tables appear in
  the local test DB.

### 7.2 Keep the PR clean (proven PR#4 pattern)
- Develop the feature **and** the Docker harness on the dev branch for testing.
- For the PR, cherry-pick **only the feature commits** (career.cgi/tmpl,
  organization.cgi, admin/organizations.*, User.pm, the migration, the JS) onto
  a clean `main`-based branch → **PR into `main`**. Do **not** include the Docker
  harness or the seed data in the PR (local-only / privacy).

### 7.3 Production cutover
- The stale simple `bw_user_career` (created 2026-07-06, never live) → **DROP**,
  then apply the v3.2 migration (3 tables). No real data lost. `mysqldump` first.
- `git pull` the deploy tree (`main`) + **graceful Apache restart** (mod_perl
  caches `lib/Bawi/*.pm`). Ensure `career.cgi` / `organization.cgi` /
  `admin/organizations.cgi` are mode **755**.
- Load the **reviewed org seed** into prod after the tables exist.

## 8. The PR#4 prototype (feature/career-tracking)
Built off stale `master` with a free-text design; two review rounds hardened it.
It is a **prototype**, superseded by this spec — **do not merge it**; salvage
its lessons only (ownership `WHERE uid`, the warning idiom, trimmed inputs). Its
`1001-01-01` sentinel is dropped in favor of `NULL`.

## 9. File summary (v3.2)

| File | Purpose | Base |
|---|---|---|
| `user/career.cgi` | career CRUD + org resolve-or-create | `degree.cgi` |
| `user/skin/default/career.tmpl` | form with type-ahead org field | `degree.tmpl` |
| `user/organization.cgi` | alias-prefix suggest endpoint (or `career.cgi?suggest=`) | small |
| `admin/organizations.cgi` | merge/alias maintenance tool | `admin/index.cgi` |
| `admin/skin/default/organizations.tmpl` | admin UI | `admin/skin/default/index.tmpl` |
| `lib/Bawi/User.pm` | career + org methods | `add_degree` style |
| `db/20260708_create_career.sql` | drop stale + create 3 tables | — |
| type-ahead widget | ~40-line vanilla JS | inline |
