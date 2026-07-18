#!/bin/bash
# Migration runner for the bawi test database.
#
# CONTRACT: dated migrations are db/YYYYMMDD_*.sql (mounted read-only at
# /bawi-migrations); lexicographic order == date order. The bawi_*.sql files
# in db/ are legacy FULL DUMPS and are never executed; any other *.sql name
# is skipped with a loud warning (rename it to the dated pattern to run it).
# Data in migrations: transforms of existing rows are fine (reseed
# regenerates data — keep seed.pl emitting the post-migration shape).
# Reference rows prod needs MAY ride in
# the migration (idempotently) for prod's sake — db/ is also the prod
# migration channel — but MUST then be mirrored in seed/seed.pl, because
# reseed truncates every base table except schema_migrations.
#
# Double-apply protection is the schema_migrations tracking table alone:
# migrations already contained in 10-schema.sql are pre-recorded as
# status='baseline' by 15-baseline.sql (which runs first and also creates the
# table); everything not recorded is executed and recorded as 'applied'.
# REFRESHING THE DUMP: update 15-baseline.sql in the same commit — a missed
# baseline entry gets re-executed: non-idempotent DDL aborts first boot
# loudly, but idempotent migrations (ALTER MODIFY, data UPDATEs, DROP IF
# EXISTS+CREATE) re-run SILENTLY — verify those rows by hand.
#
# This file is executable ON PURPOSE: the official mariadb entrypoint runs
# executable init hooks as a child process (it would source a non-executable
# one into its own shell, leaking our set -e/shopt). The child doesn't
# inherit the entrypoint's internal SQL helper functions, so both contexts
# call the plain mariadb client below:
#   a) first-boot init hook — the entrypoint's temp server listens on the
#      default socket and the root password is already set. Requires the
#      plain MARIADB_ROOT_PASSWORD env form (a _FILE/RANDOM variant would
#      break the client call below).
#   b) manual rerun on a running container (e.g. after adding a migration):
#      docker compose exec db bash /docker-entrypoint-initdb.d/20-apply-migrations.sh
set -euo pipefail

MIGRATIONS_DIR="${MIGRATIONS_DIR:-/bawi-migrations}"
DB_NAME="${MARIADB_DATABASE:?}"

sql_exec() { mariadb -uroot -p"${MARIADB_ROOT_PASSWORD:?}" --database="$DB_NAME" "$@"; }

# Query with a fail-closed error path: a failed probe must abort, not read
# as an answer (an empty result here once meant "skip this migration").
sql_query() {
    local out
    out=$(echo "$1" | sql_exec --skip-column-names --batch) \
        || { echo "[migrations] FATAL: query failed: $1" >&2; exit 1; }
    echo "$out"
}

# Connectivity first, stderr unsuppressed: a down/starting server or bad
# credentials must abort with the client's real error ("retry"), never be
# mistaken for the missing-ledger state whose remedy (down -v) is destructive.
sql_query "SELECT 1" >/dev/null

# 15-baseline.sql owns the tracking table and its baseline rows (first-boot
# init runs it before this script). With the DB reachable, a missing/empty
# table means the DB was never legitimately initialized (e.g. a first boot
# that died mid-schema, then restarted with a non-empty datadir, which skips
# init) — re-executing migrations against unknown state is wrong, fail closed.
recorded=$(sql_query "SELECT COUNT(*) FROM schema_migrations" 2>/dev/null) || recorded=""
if [ -z "$recorded" ] || [ "$recorded" = "0" ]; then
    echo "[migrations] FATAL: schema_migrations is missing or empty — this DB was not initialized by 15-baseline.sql (a failed first boot?). Rebuild with: docker compose down -v && docker compose up -d" >&2
    exit 1
fi

is_recorded() {
    local n
    n=$(sql_query "SELECT COUNT(*) FROM schema_migrations WHERE filename='$1'")
    case "$n" in
        0) return 1 ;;
        1) return 0 ;;
        # "" here means the sql_query subshell failed (its FATAL is on stderr)
        *) echo "[migrations] FATAL: unexpected probe result '$n' for $1" >&2; exit 1 ;;
    esac
}

record() {
    echo "INSERT INTO schema_migrations (filename, status) VALUES ('$1', '$2')" | sql_exec
}

shopt -s nullglob
found=0
for f in "$MIGRATIONS_DIR"/*.sql; do
    base=$(basename "$f")
    case "$base" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_*.sql) ;;
        bawi_*.sql)
            echo "[migrations] $base: legacy full dump — never executed"
            continue ;;
        *)
            echo "[migrations] WARNING: $base does not match YYYYMMDD_*.sql — NOT applied (rename it to run)" >&2
            continue ;;
    esac
    found=1
    if is_recorded "$base"; then
        echo "[migrations] $base: already recorded — skip"
        continue
    fi
    echo "[migrations] $base: applying"
    sql_exec < "$f"
    record "$base" applied
done
if [ "$found" != "1" ]; then
    # The repo always ships dated migrations; an empty dir means a broken
    # mount or MIGRATIONS_DIR override — never a state to bless silently.
    echo "[migrations] FATAL: no dated migration files found in $MIGRATIONS_DIR" >&2
    exit 1
fi

echo "[migrations] state:"
sql_query "SELECT CONCAT(filename, ' -> ', status) FROM schema_migrations ORDER BY filename"
