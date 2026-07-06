#!/bin/bash
# Guarded migration runner for the bawi test database.
#
# Applies db/*.sql (mounted at /bawi-migrations) in chronological order
# (filenames start with YYYYMMDD, so lexicographic glob order == date order),
# guarding against double-apply two ways:
#
#   1. A `schema_migrations` tracking table records every processed file.
#   2. For each known migration, an information_schema probe detects whether
#      the change is ALREADY REFLECTED in the loaded schema dump (the current
#      prod schema contains all five historical migrations); such files are
#      recorded as status='baseline' without being executed.
#
# New migration files dropped into db/ are simply executed (status='applied'):
# either re-run this script (see below) or `docker compose down -v && up` for
# a fresh init.
#
# Runs in two contexts:
#   a) automatically, as a /docker-entrypoint-initdb.d/*.sh hook on FIRST
#      container init (the official mariadb entrypoint sources it, providing
#      docker_process_sql);
#   b) manually, against a running db container:
#      docker compose exec db bash /docker-entrypoint-initdb.d/20-apply-migrations.sh
set -euo pipefail

MIGRATIONS_DIR="${MIGRATIONS_DIR:-/bawi-migrations}"
DB_NAME="${MARIADB_DATABASE:-bawi}"

if declare -F docker_process_sql >/dev/null 2>&1; then
    # initdb context (temp server on unix socket, helper provided)
    sql_exec() { docker_process_sql --database="$DB_NAME" "$@"; }
else
    # exec context on a running container
    sql_exec() { mariadb -uroot -p"${MARIADB_ROOT_PASSWORD:?}" --database="$DB_NAME" "$@"; }
fi

q() { echo "$1" | sql_exec --skip-column-names --batch; }

echo "[migrations] ensuring schema_migrations tracking table"
sql_exec <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   varchar(128) NOT NULL,
  status     enum('applied','baseline') NOT NULL,
  applied_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (filename)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL

is_recorded() {
    [ "$(q "SELECT COUNT(*) FROM schema_migrations WHERE filename='$1'")" != "0" ]
}

record() {
    echo "INSERT INTO schema_migrations (filename, status) VALUES ('$1', '$2')" | sql_exec
}

# Echo a non-zero count if the migration's effect is already present.
already_reflected() {
    case "$1" in
        20161225_add_career_enum.sql)
            q "SELECT COUNT(*) FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='bw_user_degree'
                 AND COLUMN_NAME='type' AND COLUMN_TYPE LIKE '%Postdoc%'"
            ;;
        20201030_add_expiration_days.sql)
            q "SELECT COUNT(*) FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='bw_xboard_board'
                 AND COLUMN_NAME='expire_days'"
            ;;
        20201031_create_commentref.sql)
            q "SELECT COUNT(*) FROM information_schema.TABLES
               WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='bw_xboard_commentref'"
            ;;
        20220903_add_retraction.sql)
            q "SELECT COUNT(*) FROM information_schema.COLUMNS
               WHERE TABLE_SCHEMA='$DB_NAME' AND TABLE_NAME='bw_xboard_recom'
                 AND COLUMN_NAME='retracttime'"
            ;;
        20221221_retroactive_change_delete_comment.sql)
            # Data-only fix (idempotent UPDATE). "Reflected" when no rows
            # still carry the old placeholder text — trivially true on a
            # fresh structure-only load.
            local n
            n=$(q "SELECT COUNT(*) FROM bw_xboard_comment
                   WHERE body LIKE '** Deleted by the author **'
                      OR body LIKE '*** Deleted by author ***'")
            if [ "$n" = "0" ]; then echo 1; else echo 0; fi
            ;;
        *)
            echo 0   # unknown/new migration: not reflected -> execute it
            ;;
    esac
}

shopt -s nullglob
found=0
for f in "$MIGRATIONS_DIR"/2*.sql; do
    found=1
    base=$(basename "$f")
    if is_recorded "$base"; then
        echo "[migrations] $base: already recorded — skip"
        continue
    fi
    if [ "$(already_reflected "$base")" != "0" ]; then
        echo "[migrations] $base: already reflected in schema — recording as baseline"
        record "$base" baseline
    else
        echo "[migrations] $base: applying"
        sql_exec < "$f"
        record "$base" applied
    fi
done
[ "$found" = "1" ] || echo "[migrations] WARNING: no migration files found in $MIGRATIONS_DIR"

echo "[migrations] state:"
q "SELECT CONCAT(filename, ' -> ', status) FROM schema_migrations ORDER BY filename"
