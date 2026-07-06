# Career Feature Implementation Specification

## Overview

This document specifies a separate career-tracking feature for the Bawi BBS, splitting the current combined 학위/경력 (degree/career) system into two distinct features: academic degrees and professional career experience.

## Current System Limitations

### Database Schema Issues
- `bw_user_degree.type` enum is hardcoded for academic degrees only
- `schools` table contains only academic institutions (~170 rows as of the 2018 schema dump — needs a fresh `SELECT COUNT(*)` against the live DB before this is quoted as fact)
- Fields like "advisors" and "research content" are academic-specific
- Manual admin intervention required for adding new institutions

### User Experience Issues
- Corporate career experience forced into academic degree framework
- Limited career types (only academic positions)
- No support for job positions / departments
- Synonym management for organization names not supported

## Proposed Solution

### New Database Schema

Design notes (addressing lessons already paid for in this codebase):
- **InnoDB + real foreign keys.** These tables are relational (careers reference organizations) and one operation is destructive (see admin duplicate handling), so they need referential integrity and transactions — unlike the flat MyISAM lookup tables. MariaDB 10.6 mixes engines per-table freely.
- **`utf8mb4`**, matching the codebase's own most recent migration (`db/20201031_create_commentref.sql` uses `utf8mb4`/`utf8mb4_bin`), not the superseded 3-byte `utf8` of the 2016/2018 dumps. Free-text `position`/`description`/org names must accept 4-byte input.
- **Organization type via a lookup table**, not an `ENUM` — the spec's own top complaint is that `bw_user_degree.type`'s hardcoded enum needs an `ALTER TABLE` + code edit to extend. An admin-editable lookup (the pattern `schools`/`bw_data_major` already use) fixes that.
- **`end_date IS NULL` is the single source of truth for "ongoing"** — no separate `is_current` flag to fall out of sync, and no `'0000-00-00'` sentinel (which sorts before every real date and inverts a most-recent-first timeline; the codebase's real "unset" sentinel is `'1001-01-01'`, but `NULL` is cleaner for a new table).

```sql
-- Admin-extensible organization-type lookup (replaces a hardcoded ENUM)
CREATE TABLE `bw_data_org_type` (
  `id`    smallint unsigned NOT NULL AUTO_INCREMENT,
  `code`  varchar(20)  NOT NULL,
  `label` varchar(64)  NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
-- seed: company, government, nonprofit, academic, hospital, other

CREATE TABLE `organizations` (
  `id`           int unsigned NOT NULL AUTO_INCREMENT,
  `full_name`    varchar(128) NOT NULL DEFAULT '',
  `brief_name`   varchar(32)  NOT NULL DEFAULT '',
  `org_type_id`  smallint unsigned NOT NULL,
  `url`          varchar(64)  DEFAULT NULL,
  `country_code` varchar(2)   NOT NULL DEFAULT 'KR',
  `verified`     tinyint(1)   NOT NULL DEFAULT 0,
  `created_by`   mediumint unsigned DEFAULT NULL,
  `created_date` timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `full_name` (`full_name`),
  KEY `brief_name` (`brief_name`),
  KEY `verified` (`verified`),
  CONSTRAINT `fk_org_type` FOREIGN KEY (`org_type_id`) REFERENCES `bw_data_org_type` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
-- NOTE: corporate parent/subsidiary hierarchy (parent_id) and a destructive merge
-- tool are deferred to v2 — see "Deferred to v2". v1 is flat, matching `schools`.

-- The actual stated need: many names -> one canonical organization
CREATE TABLE `organization_synonym` (
  `id`     int unsigned NOT NULL AUTO_INCREMENT,
  `org_id` int unsigned NOT NULL,
  `name`   varchar(128) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`),
  CONSTRAINT `fk_synonym_org` FOREIGN KEY (`org_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `bw_user_career` (
  `career_id`       mediumint unsigned NOT NULL AUTO_INCREMENT,
  `uid`             mediumint unsigned NOT NULL DEFAULT 0,
  `type`            enum('employment','internship','volunteer','research','military','other')
                      NOT NULL DEFAULT 'employment',
                      -- intentionally a CLOSED set (unlike org type / institutions);
                      -- extending it is a rare, deliberate migration, so an enum is acceptable here.
  `organization_id` int unsigned NOT NULL,   -- int, matching organizations.id (was smallint: type mismatch + 65k cap)
  `position`        varchar(255) NOT NULL DEFAULT '',
  `department`      varchar(255) NOT NULL DEFAULT '',
  `description`     text NOT NULL,
  `start_date`      date DEFAULT NULL,        -- NULL = unknown
  `end_date`        date DEFAULT NULL,        -- NULL = ongoing (single source of truth)
  `status`          varchar(20) NOT NULL DEFAULT 'active',
  PRIMARY KEY (`career_id`),
  KEY `uid` (`uid`),
  KEY `idx_user_current` (`uid`, `end_date`),
  KEY `idx_search` (`organization_id`, `position`),
  CONSTRAINT `fk_career_org` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
```

Most-recent-first, ongoing on top: `ORDER BY (end_date IS NULL) DESC, end_date DESC`.

## Development & Deployment

**A local test environment now exists** (branch `test-env`): a Docker stack matching production (Apache 2.4 + mod_perl2 + Perl 5.34 + MariaDB 10.6), a structure-only copy of the prod schema, deterministic synthetic data, and an admin login. The earlier "no test server → production-only stealth rollout" premise no longer holds, so this feature is built and tested off production like any normal change:

1. **Develop** on a branch off `test-env` (or `main`). Add the tables to the local DB, build `career.cgi`/`organization.cgi`/templates and the `Bawi::User` methods, and exercise them against the seeded synthetic data + admin login.
2. **No** parallel `_beta`/`_v2` files, **no** hidden-URL testing on the live box, **no** `_beta` tables in the production database, and **no** `mv`-based file swap. (On this stack `mv` is not even atomic: `ModPerl::Registry` caches `lib/Bawi/*.pm` per Apache child and does not reload on file change, so a swapped-in `profile.cgi` calling new `Bawi::User` methods 500s on still-running children until a full Apache restart.)
3. **Deploy** via the normal git flow: PR into `main`, then the standard production cutover (`git pull` on the deploy tree) with a **graceful Apache restart** to load the new modules.
4. **Schema migration:** apply to the local test DB first; on prod, run the migration during the deploy window **after a `mysqldump` backup** (see the maintenance plan). The migration is purely additive (new tables), so rollback is `git revert` + redeploy + `DROP TABLE` on the new tables — no data loss on existing tables.

## Technical Specifications

### New Files Required

| File | Purpose | Base Template | Lines Est. |
|------|---------|---------------|------------|
| `/user/career.cgi` | Career CRUD operations | `degree.cgi` | ~120 |
| `/user/skin/default/career.tmpl` | Career form UI | `degree.tmpl` | ~150 |
| `/user/organization.cgi` | Organization browsing | `school.cgi` | ~130 |
| `/user/skin/default/organization.tmpl` | Organization listing | `school.tmpl` | ~100 |
| `/admin/organizations.cgi` | Org approval/verify | New | ~150 |
| `/admin/skin/default/organizations.tmpl` | Admin UI | New | ~120 |

### Perl Module Extensions (`/lib/Bawi/User.pm`)

```perl
# Career management methods
sub get_career($)        # all career rows for a uid (1-to-many), ordered current-first
sub add_career(@)
sub update_career($@)
sub del_career($$)
sub career_set($)
sub organization_list(%)
sub add_organization(@)  # user-suggested org, verified=0 until admin approves
```

(`merge_organizations` is deferred to v2 — see below.)

### Key Features

#### User-Facing
- **Career Types**: Employment, Internship, Volunteer, Research, Military, Other
- **Organization Management**: users can suggest a new organization (created `verified=0`)
- **Synonyms**: alternate names resolve to one canonical organization (`organization_synonym`)
- **Timeline View**: chronological career progression (`end_date IS NULL` = current)
- **Privacy Controls**: show/hide specific career entries

#### Admin
- **Organization Approval**: review user-submitted organizations (`verified` flag)
- **Duplicate Detection**: surface likely-duplicate organizations (read-only report)

### Deferred to v2 (explicitly out of scope for v1)
These were scoped before the flat model was validated; defer until v1 demonstrably needs them:
- **Corporate hierarchy** (`organizations.parent_id`, parent/subsidiary).
- **Destructive merge** (`merge_organizations`) — needs the InnoDB transaction it would run in; only worth building once duplicates are a demonstrated problem.
- **Bulk import/export** of organization data.

Rationale: the existing `schools` table has served the "shared, admin-curated institution list" need for years as a *flat* table with no hierarchy and no merge tool; v1 organizations should match that proven shape plus the one genuinely new need (synonyms).

### Data Migration Strategy

```sql
-- Migration script to split existing degree data:
--  * identify career-like entries in bw_user_degree
--  * move non-academic entries into bw_user_career (+ organizations)
--  * preserve academic degrees in bw_user_degree
-- Run and verify on the test-env DB before prod.
```

## Testing Checklist (on `test-env`, against synthetic data)

### Feature
- [ ] Career CRUD (add / edit / delete) round-trips correctly
- [ ] Organization suggest → admin approve (`verified` 0→1) flow works
- [ ] Synonym lookup resolves alternate names to the canonical org
- [ ] Timeline orders current (end_date NULL) first, then by end_date desc
- [ ] User permission checks (only owner edits own career)

### Integration
- [ ] Profile page shows both degrees and career correctly
- [ ] Search includes career data (see below)
- [ ] Foreign keys reject orphan career rows / block org delete with dependents

### Production readiness
- [ ] Migration tested on the test-env DB (and on a prod-schema copy)
- [ ] `mysqldump` backup taken before the prod migration
- [ ] Graceful Apache restart verified to load new modules
- [ ] Rollback (git revert + DROP new tables) rehearsed

## Search System Integration

### Current Search Infrastructure

- **Main search** (`/main/search.cgi`, `/main/search2.cgi`): people search over `bw_xauth_passwd`/`bw_user_ki`/`bw_user_basic` (id, name, affiliation, addresses, phones); article/board search in `search2.cgi`.
- **User search** (`/user/search.cgi`): `search_affiliation()` in `Bawi::User`, with match highlighting.
- **School browsing** (`/user/school.cgi`): user counts by degree/school, listing by school, advisor grouping.

Integration adds organization name + position to people results, a career search mode, and an organization-browsing page parallel to `school.cgi`.

### New search methods in `Bawi::User.pm`

```perl
# Career search. NOTE: bw_user_career is 1-to-many per user, so DO NOT use
# selectall_hashref keyed by a.id (it silently overwrites all but one row per
# user). Return every matching career row and aggregate per user in Perl.
sub search_career {
    my ($self, $keyword) = @_;
    my $sql = qq(
        select c.career_id, a.id, a.name, b.ki, c.position, o.full_name as organization
        from bw_xauth_passwd a
        join bw_user_ki      b on a.uid = b.uid
        join bw_user_career  c on a.uid = c.uid
        join organizations   o on c.organization_id = o.id
        left join organization_synonym s on s.org_id = o.id
        where c.position like ? or o.full_name like ? or o.brief_name like ?
           or s.name like ? or a.id like ? or a.name like ?
        order by b.ki, a.name, c.career_id);
    my $rv = $DBH->selectall_arrayref($sql, { Slice => {} }, ("\%$keyword\%") x 6);
    # group $rv by a.id in Perl so a user with multiple matching careers keeps them all
    return $rv;
}

# Organization statistics (parallel to school stats). Keyed by org id, which
# IS unique in a GROUP BY o.id result, so a hashref key is safe here.
sub organization_stats {
    my ($self, $type_code) = @_;
    my $sql = qq(
        select o.full_name as organization, o.id, count(*) as cnt
        from organizations o
        join bw_user_career c on o.id = c.organization_id
        join bw_data_org_type t on o.org_type_id = t.id
        where (? = '' or t.code = ?)
        group by o.id order by cnt desc, organization);
    return $DBH->selectall_arrayref($sql, { Slice => {} }, $type_code, $type_code);
}
```

### Search UI

New search categories: People by Academic Background (current), People by Career Background (new), People by Organization, Combined. Templates extend the existing `search.tmpl` family (no parallel `_beta` files — developed and tested on `test-env`).

**Enhanced people-result format:**
```
[기수] 이름(ID):
  Academic: [학위] 학교명, 학과
  Career:   [직급] 회사명, 부서 [기간]
  Contact:  전화번호
```

## Performance Considerations

```sql
-- Indexes are declared inline in the CREATE TABLEs above:
--   bw_user_career: idx_user_current (uid, end_date), idx_search (organization_id, position)
--   organizations:  full_name, brief_name, verified
-- Add a FULLTEXT index only if LIKE-prefix search proves too slow at real volume:
ALTER TABLE organizations ADD FULLTEXT INDEX ft_names (full_name, brief_name);
```

Caching: organization-name autocomplete and organization/position statistics are the obvious cache targets if profiled as hot.

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
- Reduced admin overhead for organization management (self-service + synonyms)
- Career-based user discovery via search

---

**Document Version**: 2.0
**Created**: 2025-07-24
**Revised**: 2026-07-06 (removed the obsolete production-only "stealth" rollout now that a local `test-env` exists; InnoDB + FKs; `utf8mb4`; org-type lookup table; `end_date IS NULL` as the sole "current" signal; synonym table; deferred hierarchy/merge/bulk to v2; fixed `search_career`'s multi-row drop)
**Status**: Specification Phase
