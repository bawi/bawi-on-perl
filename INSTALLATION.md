# Installation — local Docker test environment

Reproducible **local** Docker environment for the bawi BBS (Apache 2.4 +
mod_perl2 + Perl 5.34 + MariaDB 10.6 on Ubuntu 22.04 — same stack as prod),
with a structure-only copy of the production schema and deterministic
**synthetic** data.

> **LOCAL-ONLY, BY CONSTRUCTION.** All published ports are bound to
> `127.0.0.1` in `docker-compose.yml`, so the stack is reachable **only from
> this machine**, never the LAN/internet. Keep it that way: a bare `8080:80`
> would publish on all interfaces. Everything in here is throwaway/fake:
> no real credentials, no real user data.

## Prerequisites

Docker (Desktop) running; works with legacy `docker-compose` 1.29+ or modern
`docker compose` — use whichever your installation has.

## Run it

```sh
cd <repo>
docker compose up -d --build    # or: docker-compose up -d --build
```

First start takes a few minutes: the web image builds, and the db container
creates database `bawi`, loads `docker/db/init/10-schema.sql` (prod schema,
structure only, no rows), pre-records the migrations that dump already
contains (`docker/db/init/15-baseline.sql`), then executes the newer
`db/YYYYMMDD_*.sql` migrations. The app's config is the tracked
`docker/conf/*.conf`, bind-mounted read-only onto `conf/` inside the
container (prod keeps its real configs untracked in `conf/`, which stays
gitignored). Any host-side `conf/*.conf` — including copies materialized by
older versions of this environment — is ignored inside the container and safe
to delete.

Ports default to **8080** (web) and **3307** (db) on localhost. Each
uniquely-named checkout gets its own compose project (project = directory
basename; same-named checkouts would share one — use `docker compose -p` to
disambiguate). To run stacks side by side, give later ones their own ports —
persistently, via a gitignored `.env`:

```sh
printf 'BAWI_HTTP_PORT=8081\nBAWI_DB_PORT=3308\n' > .env
docker compose up -d --build
```

Then load the synthetic data (idempotent — safe to re-run any time):

```sh
./seed/reseed.sh                # = docker compose exec web perl /home/bawi/bawi-spring/seed/seed.pl
```

Open **http://localhost:8080/** — you'll get the login page.

| account | password | notes |
|---|---|---|
| `root` | `test1234` | admin (matches the hardcoded admin list in `Bawi::Auth`) |
| `testuser02` … `testuser50` | `test1234` | regular synthetic members |

Useful URLs once logged in:

- `http://localhost:8080/board/index.cgi` — bookmarks / board overview
- `http://localhost:8080/board/boards.cgi` — board list
- `http://localhost:8080/main/news.cgi` — recent articles
- `http://localhost:8080/main/note.cgi` — notes (40 seeded; each of the first 10 users has 1 unread)
- `http://localhost:8080/main/db-test.cgi` — plain-text DB connectivity check

## Everyday commands

Run these from the checkout that launched the stack — compose resolves
containers per-project, i.e. per-directory.

```sh
docker compose logs -f web            # Apache error+access log (stderr/stdout)
docker compose restart web            # REQUIRED after editing lib/Bawi/*.pm
                                      # (mod_perl caches modules per child;
                                      #  .cgi and docker/conf/*.conf edits are
                                      #  picked up on the next request)
./seed/reseed.sh                      # wipe + reseed synthetic data
docker compose exec web bash          # shell in the web container
mysql -h 127.0.0.1 -P 3307 -u bawi_test -pbawi-local-test-pw bawi   # DB from host (your BAWI_DB_PORT if overridden)
docker compose down                   # stop (data volumes kept)
docker compose down -v                # stop and DESTROY db + attachment + photo volumes
```

The repo working tree is bind-mounted at `/home/bawi/bawi-spring` (the exact
prod path hardcoded in `apache2/startup.pl`), so host edits are live.

## Run a single .cgi

Through the real stack (recommended — exercises mod_perl exactly like prod):

```sh
curl -s http://localhost:8080/main/db-test.cgi

# authenticated: log in once, keep the session cookie
curl -s -c /tmp/bawi.jar -d 'id=testuser02&passwd=test1234' \
     http://localhost:8080/main/login.cgi -o /dev/null
curl -s -b /tmp/bawi.jar http://localhost:8080/board/index.cgi
```

From a shell in the container (plain-CGI semantics, handy for compile checks
and print-debugging; note mod_perl-only behaviors won't reproduce here):

```sh
docker compose exec web bash
cd /home/bawi/bawi-spring/main
export BAWI_PERL_HOME=/home/bawi/bawi-spring/ BAWI_DATA_HOME=/home/bawi/bawi-data/
perl -I/home/bawi/bawi-spring/lib -c db-test.cgi        # compile check
REQUEST_METHOD=GET QUERY_STRING='' perl -I/home/bawi/bawi-spring/lib db-test.cgi
```

## Migrations

Dated migrations (`db/YYYYMMDD_*.sql`; the `bawi_*.sql` files are legacy full
dumps and are never executed) are applied on first DB init by
`docker/db/init/20-apply-migrations.sh`. Double-apply protection is the
`schema_migrations` tracking table: migrations already contained in the
schema dump are pre-recorded as `baseline` by `docker/db/init/15-baseline.sql`,
everything else runs and is recorded as `applied` (every dated `db/` file
newer than the dump — the runner's closing state listing shows which). The
runner logs a line per file, so a migration it didn't pick up is visible in
`docker compose logs db`.

Migrations must be structure-only or idempotent data transforms. Reference
rows a migration would INSERT belong in `seed/seed.pl` instead — reseed
truncates every base table except `schema_migrations`, so migration-inserted
rows would silently vanish on the next reseed.

After adding a new `db/YYYYMMDD_*.sql` to a *running* env (from the checkout
that launched it):

```sh
docker compose exec db bash /docker-entrypoint-initdb.d/20-apply-migrations.sh
```

To rebuild the DB from scratch: `docker compose down -v && docker compose up -d`
then reseed.

**Refreshing `10-schema.sql` from prod:** update `15-baseline.sql` in the same
commit (see the header comments in both files). A migration the new dump
reflects but the baseline list misses gets re-executed — non-idempotent DDL
aborts first boot loudly, but idempotent migrations (ALTER MODIFY, data
UPDATEs, DROP IF EXISTS+CREATE) re-run silently, so verify those rows by
hand. If a first boot fails partway, `docker compose down -v` before
retrying — a half-initialized data dir skips init on the next start.

## Validation checklist (what "working" looks like)

1. `docker compose ps` — the db and web containers both `Up`.
2. `docker compose exec -T db mysql -u bawi_test -pbawi-local-test-pw bawi -e "SHOW TABLES" | wc -l` → 63 lines: 1 column-header line + 61 tables (incl. `schema_migrations`) + the `freq_bookmark` view. (Grows by one per table-adding migration — cross-check against the runner's state listing in `docker compose logs db`.)
3. `curl -s http://localhost:8080/main/db-test.cgi` → three `before query:/after query:/dbh->errstr:` lines then the six seeded board titles (no 500).
4. `curl -s http://localhost:8080/` → login page HTML (200).
5. Login POST (see above) → `302` with `Set-Cookie: bawi_session=…`.
6. `curl -s -b /tmp/bawi.jar http://localhost:8080/board/index.cgi` → bookmark page listing seeded boards.
7. Markdown render path: read a seeded markdown article (free board, e.g. `curl -s -b /tmp/bawi.jar 'http://localhost:8080/board/read.cgi?bid=2&aid=36'`; markdown articles are free-board nos 20-24, `aid` = 15 + article_no — recompute if `@BOARDS` changes) → body contains rendered HTML (`<h2>`, `<code>`), and `SELECT COUNT(*) FROM bw_xboard_body_html` goes from 0 to ≥1 after the read.
8. `docker compose logs web | grep -i "error"` → no Perl compile errors.

Known-broken pages (repo gap, **not** an environment fault): `board/x.cgi`,
`main/menu.cgi`, `board/addgroup.cgi`, `board/apply.cgi`, and
`user/company.cgi` 500 because their skin `*.tmpl` files were never committed
to git. The admin pages are fine (their templates are in git);
`admin/uphoto.cgi` 500s only until a photo exists under `/home/bawi/photo_attach`
(provisioned as a named volume, empty on first boot). The classic UI works
without any of them.

## Legacy setup

The historical native-macOS (El Capitan era) instructions live on the
`local` branch; the Docker environment above supersedes them.
