# Installation — local Docker test environment

Reproducible **local** Docker environment for the bawi BBS (Apache 2.4 +
mod_perl2 + Perl 5.34 + MariaDB 10.6 on Ubuntu 22.04 — same stack as prod),
with a structure-only copy of the production schema and deterministic
**synthetic** data.

> **LOCAL-ONLY, BY CONSTRUCTION.** All published ports are bound to
> `127.0.0.1` in `docker-compose.yml` (`127.0.0.1:8080:80`,
> `127.0.0.1:3307:3306`), so the stack is reachable **only from this
> machine**, never the LAN/internet. Keep it that way: a bare `8080:80`
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
structure only, no rows), and runs the guarded migration runner over
`db/*.sql`. The web entrypoint materializes `conf/*.conf` (gitignored — prod
keeps its real configs untracked there) from `docker/conf/*.conf` unless they
already exist; delete yours to regenerate.

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
- `http://localhost:8080/main/note.cgi` — notes (10 seeded unread)
- `http://localhost:8080/main/db-test.cgi` — plain-text DB connectivity check

## Everyday commands

```sh
docker compose logs -f web            # Apache error+access log (stderr/stdout)
docker compose restart web            # REQUIRED after editing lib/Bawi/*.pm
                                      # (mod_perl caches modules per child;
                                      #  .cgi edits are picked up automatically)
./seed/reseed.sh                      # wipe + reseed synthetic data
docker compose exec web bash          # shell in the web container
mysql -h 127.0.0.1 -P 3307 -u bawi_test -pbawi-local-test-pw bawi   # DB from host
docker compose down                   # stop (data volumes kept)
docker compose down -v                # stop and DESTROY db + attachment volumes
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

`db/2*.sql` are applied on first DB init by
`docker/db/init/20-apply-migrations.sh`, guarded two ways (a
`schema_migrations` tracking table + information_schema probes), so
migrations already contained in the schema dump are recorded as `baseline`
and never double-applied, while migrations newer than the dump (currently the
career-v3.2 and body_html render-cache tables) are executed and recorded as
`applied`. After adding a new `db/YYYYMMDD_*.sql` to a *running* env:

```sh
docker compose exec db bash /docker-entrypoint-initdb.d/20-apply-migrations.sh
```

To rebuild the DB from scratch: `docker compose down -v && docker compose up -d`
then reseed.

## Validation checklist (what "working" looks like)

1. `docker compose ps` — `bawi-test-db` and `bawi-test-web` both `Up`.
2. `docker compose exec db mysql -u bawi_test -pbawi-local-test-pw bawi -e "SHOW TABLES" | wc -l` → 63 (62 tables incl. `schema_migrations` + header).
3. `curl -s http://localhost:8080/main/db-test.cgi` → three `before query:/after query:/dbh->errstr:` lines then the six seeded board titles (no 500).
4. `curl -s http://localhost:8080/` → login page HTML (200).
5. Login POST (see above) → `302` with `Set-Cookie: bawi_session=…`.
6. `curl -s -b /tmp/bawi.jar http://localhost:8080/board/index.cgi` → bookmark page listing seeded boards.
7. `docker compose logs web | grep -i "error"` → no Perl compile errors.

Known-broken pages (repo gap, **not** an environment fault): `board/x.cgi`,
`main/menu.cgi`, `board/addgroup.cgi`, `board/apply.cgi`, `user/company.cgi`
and the four `admin/*.cgi` pages 500 because their skin `*.tmpl` files were
never committed to git (they exist only on the prod filesystem). The classic
UI works without them.

## Legacy setup

The historical native-macOS (El Capitan era) instructions live on the
`local` branch; the Docker environment above supersedes them.
