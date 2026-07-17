#!/bin/bash
# Migration runner for the bawi test database.
#
# CONTRACT: dated migrations are db/YYYYMMDD_*.sql (mounted read-only at
# /bawi-migrations); lexicographic order == date order. The bawi_*.sql files
# in db/ are legacy FULL DUMPS and are never executed; any other *.sql name
# is skipped with a loud warning (rename it to the dated pattern to run it).
#
# Double-apply protection is the schema_migrations tracking table alone:
# migrations already contained in 10-schema.sql are pre-recorded as
# status='baseline' by 15-baseline.sql (which runs first and also creates the
# table); everything not recorded is executed and recorded as 'applied'.
# REFRESHING THE DUMP: update 15-baseline.sql in the same commit — a
# migration the new dump contains but the baseline list misses will be
# re-executed and abort first boot.
#
# This file is executable ON PURPOSE: the official mariadb entrypoint runs
# executable init hooks as a child process (it would source a non-executable
# one into its own shell, leaking our set -e/shopt). Both contexts therefore
# use the plain client below:
#   a) first-boot init hook — the entrypoint's temp server listens on the
#      default socket and the root password is already set. Requires the
#      plain MARIADB_ROOT_PASSWORD env form (a _FILE/RANDOM variant would
#      break the client call below).
#   b) manual rerun on a running container (e.g. after adding a migration):
#      docker compose exec db bash /docker-entrypoint-initdb.d/20-apply-migrations.sh
set -euo pipefail

MIGRATIONS_DIR="${MIGRATIONS_DIR:-/bawi-migrations}"
DB_NAME="${MARIADB_DATABASE:-bawi}"

sql_exec() { mariadb -uroot -p"${MARIADB_ROOT_PASSWORD:?}" --database="$DB_NAME" "$@"; }

# Scalar query with a fail-closed error path: a failed probe must abort, not
# read as an answer (an empty result here once meant "skip this migration").
sql_query() {
    local out
    out=$(echo "$1" | sql_exec --skip-column-names --batch) \
        || { echo "[migrations] FATAL: query failed: $1" >&2; exit 1; }
    echo "$out"
}

# 15-baseline.sql creates the tracking table on first init; ensure it exists
# for manual reruns against DBs initialized before that file existed.
sql_exec <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   varchar(128) NOT NULL,
  status     enum('applied','baseline') NOT NULL,
  applied_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (filename)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL

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
[ "$found" = "1" ] || echo "[migrations] WARNING: no dated migration files found in $MIGRATIONS_DIR"

echo "[migrations] state:"
sql_query "SELECT CONCAT(filename, ' -> ', status) FROM schema_migrations ORDER BY filename"
