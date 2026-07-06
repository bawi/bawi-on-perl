# Career Feature Implementation Specification

## Overview

This document specifies a separate career-tracking feature for the Bawi BBS, splitting the current combined 학위/경력 (degree/career) system into two distinct features: academic degrees and professional career experience. It is deliberately modeled on the existing **학력** implementation (`bw_user_degree` + `schools`, `user/degree.cgi`, `user/school.cgi`) — flat tables, direct DBI, compact code — so it stays as light and fast as the rest of the system.

## Current System Limitations

### Database Schema Issues
- `bw_user_degree.type` enum mixes academic degrees and career-ish statuses (the 2016 `add_career_enum` migration bolted Postdoc/Resident/Fellow onto it — the very hack this feature unwinds)
- `schools` table contains only academic institutions (~170 rows as of the 2018 schema dump — get a fresh `SELECT COUNT(*)` before quoting this as fact)
- Fields like "advisors" and "research content" are academic-specific
- Manual admin intervention required for adding new institutions

### User Experience Issues
- Corporate career experience forced into academic degree framework
- No support for job positions / departments
- No self-service way to add an organization

## Proposed Solution

### New Database Schema

Design notes — light, matching the 학력 grain, with three cheap correctness wins:

- **MyISAM, flat, no foreign keys** — mirroring `bw_user_degree`/`schools`. The whole schema is MyISAM with zero FKs, and the codebase uses no transactions or `RaiseError` (`lib/Bawi/DBI.pm`), so InnoDB's benefits would be unreachable — and an FK rejection combined with the house's unchecked write pattern (`user/degree.cgi` assigns `add_degree(...)` and never checks the return) would render a "saved" page that saved nothing, a silent-failure class the no-FK degree system doesn't have. The no-FK tradeoff (a hand-deleted org hides its careers via the inner join, exactly as a deleted school hides degrees today) is one the degree system has lived with for years — admins simply don't hard-delete referenced rows. If a v2 merge tool ever ships, `ALTER TABLE … ENGINE=InnoDB` on two small tables is a cheap migration *at that point*.
- **`utf8` (default `utf8_general_ci`)** — matching `schools`/`bw_user_degree`/`bw_user_basic` (all `DEFAULT CHARSET=utf8`) **and** the app's actual DB connection, which negotiates plain `utf8` (there is no `mysql_enable_utf8mb4` in `lib/Bawi/DBI.pm`). This keeps org/position `LIKE` search **case-insensitive** — the same behavior as the existing `search_affiliation` on `bw_user_basic.affiliation`. (An earlier draft used `utf8mb4`/`utf8mb4_bin` copied from `bw_xboard_commentref`, but that table has only integer columns, so its binary collation never exercised text search: `_bin` would have made org/name search case-*sensitive*, and true 4-byte storage would additionally need a system-wide connection-charset change. Both fight the grain. If 4-byte support is ever wanted — emoji, astral-plane Hanja — do it system-wide as a schema + `DBI` connection change, not piecemeal on this one feature.)
- **`org_type` as an `enum`**, mirroring `bw_user_degree.type` — the house style (11 enums in the schema; extending one is a one-line `ALTER`, done once in a decade). A lookup table would save nothing (type labels are hardcoded in the template either way) and only adds a JOIN to every stats query.
- **`end_date IS NULL` = ongoing** — a single source of truth: no `is_current` flag to desync, and no `'0000-00-00'` sentinel. (The reason to avoid the zero-date is that it sorts *before* every real date and would invert a most-recent-first timeline — not strict mode, which MariaDB 10.6's default `sql_mode` doesn't enforce on MyISAM anyway.) This is even lighter than the degree system's `'1001-01-01'` sentinel, which needs special-case code in four places.

```sql
-- db/20260706_create_career.sql   (additive; rollback = DROP TABLE x2)

CREATE TABLE `organizations` (
  `id`           int(10) unsigned NOT NULL AUTO_INCREMENT,
  `full_name`    varchar(128) NOT NULL DEFAULT '',
  `brief_name`   varchar(32)  NOT NULL DEFAULT '',
  `org_type`     enum('company','government','nonprofit','academic','hospital','other')
                   NOT NULL DEFAULT 'company',
  `url`          varchar(64)  DEFAULT NULL,
  `country_code` varchar(2)   NOT NULL DEFAULT 'KR',
  `verified`     tinyint(1)   NOT NULL DEFAULT 0,
  `created_by`   mediumint(8) unsigned NOT NULL DEFAULT 0,
  `created_date` timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `full_name` (`full_name`),
  KEY `brief_name` (`brief_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
-- mirrors `schools` (bawi_20180410.sql:1094) + the minimal self-service columns
-- (verified / created_by / created_date) for the one genuinely new workflow:
-- user-suggested organizations with admin approval.

CREATE TABLE `bw_user_career` (
  `career_id`       mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uid`             mediumint(8) unsigned NOT NULL DEFAULT 0,
  `type`            enum('employment','internship','volunteer','research','military','other')
                      NOT NULL DEFAULT 'employment',
  `organization_id` int(10) unsigned NOT NULL DEFAULT 0,  -- int, matches organizations.id
                      -- (degree uses smallint school_id vs int schools.id — a latent mismatch we don't repeat)
  `position`        varchar(255) NOT NULL DEFAULT '',
  `department`      varchar(255) NOT NULL DEFAULT '',
  `description`     text NOT NULL,
  `start_date`      date DEFAULT NULL,   -- NULL = unknown
  `end_date`        date DEFAULT NULL,   -- NULL = ongoing (single source of truth)
  PRIMARY KEY (`career_id`),
  KEY `uid` (`uid`),
  KEY `organization_id` (`organization_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
-- mirrors bw_user_degree (bawi_20180410.sql:359): same key set and shape, minus the date sentinels.
```

Most-recent-first, ongoing on top: `ORDER BY (end_date IS NULL) DESC, end_date DESC`.

This is ~2 tables + ~7 small methods + 6 files (4 user-facing, matching 학력; + 2 admin for the org-approval workflow 학력 has no parallel for).

## Development & Deployment

**A local test environment now exists** (branch `test-env`): a Docker stack matching production (Apache 2.4 + mod_perl2 + Perl 5.34 + MariaDB 10.6), a structure-only copy of the prod schema, deterministic synthetic data, and an admin login. So this feature is built and tested off production like any normal change — the earlier "no test server → production-only stealth rollout" premise no longer holds:

1. **Develop** on a branch off `test-env` (or `main`); add the tables to the local DB and build against the seeded synthetic data + admin login.
2. **No** parallel `_beta`/`_v2` files, hidden-URL testing on the live box, `_beta` tables in the prod DB, or `mv`-based file swap. (On this stack `mv` isn't even atomic: `ModPerl::Registry` caches `lib/Bawi/*.pm` per Apache child and won't reload on file change — a swapped-in `profile.cgi` calling new `Bawi::User` methods 500s on running children until a full restart.)
3. **Deploy** via the normal git flow: PR into `main`, then the standard production cutover (`git pull` on the deploy tree) with a **graceful Apache restart** to load the new modules.
4. **Schema migration:** apply to the local test DB first; on prod, run it during the deploy window **after a `mysqldump` backup**. Purely additive (new tables), so rollback is `git revert` + redeploy + `DROP TABLE` on the two new tables — no risk to existing tables.

## Technical Specifications

### New Files Required

| File | Purpose | Base Template | Lines Est. |
|------|---------|---------------|------------|
| `/user/career.cgi` | Career CRUD operations | `degree.cgi` | ~120 |
| `/user/skin/default/career.tmpl` | Career form UI | `degree.tmpl` | ~150 |
| `/user/organization.cgi` | Organization browsing | `school.cgi` | ~130 |
| `/user/skin/default/organization.tmpl` | Organization listing | `school.tmpl` | ~100 |
| `/admin/organizations.cgi` | Org approval/verify | New | ~120 |
| `/admin/skin/default/organizations.tmpl` | Admin UI | New | ~100 |

### Perl Module Extensions (`/lib/Bawi/User.pm`)

Written in the 4-line direct-DBI style of `add_degree`/`update_degree`/`del_degree`:

```perl
sub get_career($)        # all career rows for a uid (1-to-many), ordered current-first
sub add_career(@)
sub update_career($@)
sub del_career($$)
sub career_set($)
sub organization_list(%)
sub add_organization(@)  # user-suggested org, verified=0 until an admin approves
```

### Key Features

#### User-Facing
- **Career Types**: Employment, Internship, Volunteer, Research, Military, Other
- **Organization Management**: users can suggest a new organization (created `verified=0`)
- **Timeline View**: chronological career progression (`end_date IS NULL` = current)

#### Admin
- **Organization Approval**: review user-submitted organizations (`verified` flag)
- **Duplicate Detection**: a read-only report surfacing likely-duplicate organizations

### Deferred to v2 (explicitly out of scope for v1)
Scoped before the flat model was validated; add only when v1 demonstrably needs them:
- **Corporate hierarchy** (`organizations.parent_id`, parent/subsidiary).
- **Destructive merge** (`merge_organizations`) — the one operation that would want a transaction; if built, `ALTER … ENGINE=InnoDB` the two tables at that point. Until then dedup is two hand-SQL statements (`UPDATE bw_user_career SET organization_id=X WHERE organization_id=Y; DELETE FROM organizations WHERE id=Y`), exactly how `schools` is curated today.
- **Bulk import/export** of organization data.
- **Name synonyms** (alternate names → one canonical org). Deferred because there is no natural write path in v1 and `schools` has served the shared-list need with `full_name`+`brief_name` alone. Add in v2 *with* a write path — the natural one: an admin rejecting a suggested org as a duplicate of X folds its name into X's synonyms.
- **Org-type lookup table** — only if the `enum` ever proves too limiting (a one-line `ALTER` has sufficed for the degree enum for a decade).
- **Per-entry privacy** (show/hide specific career entries) — needs a `visible tinyint(1) NOT NULL DEFAULT 1` column threaded through `career_set` / `search_career`'s WHERE / the profile-display path. 학력 has no equivalent, so it's deferred until actually wanted rather than shipped as a toggle with nothing to persist to.

### Data Migration Strategy

```sql
-- Migration script to split existing degree data:
--   * identify career-like entries in bw_user_degree
--   * move non-academic entries into bw_user_career (+ organizations)
--   * preserve academic degrees in bw_user_degree
-- Type crosswalk for the degree-enum values this feature unwinds (confirm with the
-- domain owner before running): Postdoc -> research, Resident -> employment, Fellow -> employment.
-- Run and verify on the test-env DB before prod.
```

## Testing Checklist (on `test-env`, against synthetic data)

### Feature
- [ ] Career CRUD (add / edit / delete) round-trips correctly
- [ ] Organization suggest → admin approve (`verified` 0→1) flow works
- [ ] Timeline orders current (`end_date` NULL) first, then by `end_date` desc
- [ ] User permission checks (only owner edits own career)

### Integration
- [ ] Profile page shows both degrees and career correctly
- [ ] Search includes career data (see below)

### Production readiness
- [ ] Migration tested on the test-env DB (and on a prod-schema copy)
- [ ] `mysqldump` backup taken before the prod migration
- [ ] Graceful Apache restart verified to load new modules
- [ ] Rollback (git revert + DROP new tables) rehearsed

## Search System Integration

### Current Search Infrastructure
- **Main search** (`/main/search.cgi`, `/main/search2.cgi`): people search over `bw_xauth_passwd`/`bw_user_ki`/`bw_user_basic`; article/board search in `search2.cgi`.
- **User search** (`/user/search.cgi`): `search_affiliation()` in `Bawi::User`, with match highlighting.
- **School browsing** (`/user/school.cgi`): user counts by degree/school, listing by school, advisor grouping.

Integration adds organization name + position to people results, a career search mode, and an organization-browsing page parallel to `school.cgi`.

### New search methods in `Bawi::User.pm`

```perl
# Career search. NOTE: bw_user_career is 1-to-many per user, so DO NOT use
# selectall_hashref keyed by a.id — it silently overwrites all but one row per
# user (search_affiliation gets away with it only because bw_user_basic is 1:1,
# lib/Bawi/User.pm:719). Return every matching row and group per user in Perl.
sub search_career {
    my ($self, $keyword) = @_;
    my $sql = qq(
        select c.career_id, a.id, a.name, b.ki, c.position, o.full_name as organization
        from bw_xauth_passwd a
        join bw_user_ki      b on a.uid = b.uid
        join bw_user_career  c on a.uid = c.uid
        join organizations   o on c.organization_id = o.id
        where c.position like ? or o.full_name like ? or o.brief_name like ?
           or a.id like ? or a.name like ?
        order by b.ki, a.name, c.career_id);
    my $rv = $DBH->selectall_arrayref($sql, { Slice => {} }, ("\%$keyword\%") x 5);
    # group $rv by a.id in Perl so a user with several matching careers keeps them all
    return $rv;
}

# Organization statistics (parallel to degree_stat in school.cgi, which filters
# directly on the enum: `b.type=?`). Keyed by org id, unique in a GROUP BY o.id.
sub organization_stats {
    my ($self, $type) = @_;
    $type //= '';   # normalize undef -> '' so the "all types" sentinel below can't bind NULL
    my $sql = qq(
        select o.full_name as organization, o.id, count(*) as cnt
        from organizations o
        join bw_user_career c on o.id = c.organization_id
        where (? = '' or o.org_type = ?)
        group by o.id order by cnt desc, organization);
    return $DBH->selectall_arrayref($sql, { Slice => {} }, $type, $type);
}
```

### Search UI
New categories: People by Academic Background (current), People by Career Background (new), People by Organization, Combined. Templates extend the existing `search.tmpl` family — developed and tested on `test-env`, no parallel `_beta` files.

**Enhanced people-result format:**
```
[기수] 이름(ID):
  Academic: [학위] 학교명, 학과
  Career:   [직급] 회사명, 부서 [기간]
  Contact:  전화번호
```

## Performance Considerations

Indexes match the degree grain: `bw_user_career` has `KEY uid` (a user has <10 rows — no index needed for the timeline sort) and `KEY organization_id`; `organizations` has `KEY full_name`, `KEY brief_name`. Note `position LIKE '%kw%'` has a leading wildcard, so a `position` index wouldn't be used — don't add one. Add a FULLTEXT index only if LIKE-prefix search on org names proves too slow at real volume:

```sql
ALTER TABLE organizations ADD FULLTEXT INDEX ft_names (full_name, brief_name);
```
Before adding it, check the server's `ft_min_word_len` — MyISAM's default of 4 silently drops short `brief_name`s like LG/SK/KT/CJ; use boolean-mode with truncation, or lower the threshold, if those must match.

Caching: organization-name autocomplete and organization/position statistics are the obvious targets if profiled as hot.

## Timeline Estimate

| Phase | Deliverables |
|-------|--------------|
| 1 | Schema + `Bawi::User` career/org methods; local dev on `test-env` |
| 2 | Career + organization UI (user); admin approval/verify UI |
| 3 | Search integration (career + organization modes) |
| 4 | Migration rehearsal, PR into `main`, prod cutover + graceful restart |

## Success Metrics

- Successful, backup-protected data migration without loss
- User adoption of career features; improved profile completeness
- Reduced admin overhead for organization management (self-service org suggestions)
- Career-based user discovery via search

---

**Document Version**: 3.1
**Created**: 2025-07-24
**Revised**: 2026-07-06 — v2 removed the obsolete production-only "stealth" rollout (a local `test-env` now exists) and fixed real bugs (id-width mismatch, `selectall_hashref` row-clobbering, sentinel sort inversion); v3 pulled the design back to the lightweight 학력 grain (flat MyISAM, no FKs, `enum` org type; dropped the org-type lookup, synonym table, `status` column, composite indexes) while keeping `end_date IS NULL`; v3.1 reverted the charset to plain `utf8`/`utf8_general_ci` to match `schools` and the actual utf8 DB connection (fixes case-sensitive search + sidesteps a connection-charset change), guarded `organization_stats` against an `undef`→zero-rows sentinel, and deferred the unbacked per-entry-privacy toggle to v2.
**Status**: Specification Phase
