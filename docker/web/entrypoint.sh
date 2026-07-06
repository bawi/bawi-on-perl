#!/bin/bash
# Entrypoint for the bawi test web container.
# 1. Prepare BAWI_DATA_HOME (attachment dir) with www-data ownership.
# 2. Wait (bounded) for MariaDB so first-request behavior is deterministic.
# 3. Run Apache in the foreground.
set -e

DATA_HOME=/home/bawi/bawi-data
mkdir -p "$DATA_HOME/attach" "$DATA_HOME/tmp"
chown -R www-data:www-data "$DATA_HOME"

# Provide app config: conf/*.conf is gitignored (prod keeps its real configs
# untracked there), so materialize the local test configs from docker/conf/
# into the bind-mounted tree unless the host already has them.
for f in /home/bawi/bawi-spring/docker/conf/*.conf; do
    t="/home/bawi/bawi-spring/conf/$(basename "$f")"
    [ -e "$t" ] || cp "$f" "$t"
done

# Pass-through: `docker run <image> <cmd>` / compose `command:` runs <cmd>
# instead of Apache (skips the DB wait).
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

DB_HOST="${BAWI_DB_HOST:-db}"
DB_NAME="${BAWI_DB_NAME:-bawi}"
DB_USER="${BAWI_DB_USER:-bawi_test}"
DB_PASS="${BAWI_DB_PASS:-bawi-local-test-pw}"

echo "[entrypoint] waiting for MariaDB at ${DB_HOST} (max 90s) ..."
for i in $(seq 1 90); do
    if mariadb -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
               -e 'SELECT 1' >/dev/null 2>&1; then
        echo "[entrypoint] database is up (after ${i}s)"
        break
    fi
    if [ "$i" -eq 90 ]; then
        echo "[entrypoint] WARNING: DB not reachable after 90s; starting Apache anyway" >&2
    fi
    sleep 1
done

# Apache::DBI connects lazily per request, so Apache can start regardless.
. /etc/apache2/envvars
exec apache2 -D FOREGROUND
