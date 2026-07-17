#!/bin/bash
# Entrypoint for the bawi test web container.
# 1. Prepare BAWI_DATA_HOME (attachments) and the photo dir with www-data
#    ownership. App config needs no step here: docker-compose.yml bind-mounts
#    docker/conf/ read-only onto conf/, so the tracked test configs are always
#    the live ones (edit docker/conf/*.conf on the host — the app re-reads
#    configs on every request, no restart needed).
# 2. Wait (bounded) for MariaDB so first-request behavior is deterministic.
# 3. Run Apache in the foreground.
set -e

DATA_HOME=/home/bawi/bawi-data
mkdir -p "$DATA_HOME/attach" "$DATA_HOME/tmp"
# Photo storage: admin/uphoto.cgi, user/upload_photo.cgi et al. hardcode this
# prod path; without it every photo page/upload 500s. The updated/ subdir is
# where admin/photo.cgi renames processed uploads.
PHOTO_HOME=/home/bawi/photo_attach
mkdir -p "$PHOTO_HOME/updated"
chown -R www-data:www-data "$DATA_HOME" "$PHOTO_HOME"

# Pass-through: `docker run <image> <cmd>` / compose `command:` runs <cmd>
# instead of Apache (skips the DB wait).
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

DB_HOST="${BAWI_DB_HOST:-db}"
DB_NAME="${BAWI_DB_NAME:-bawi}"
DB_USER="${BAWI_DB_USER:-bawi_test}"
DB_PASS="${BAWI_DB_PASS:-bawi-local-test-pw}"

probe() { mariadb -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e 'SELECT 1' >/dev/null; }

echo "[entrypoint] waiting for MariaDB at ${DB_HOST} (max 90s) ..."
for i in $(seq 1 90); do
    if probe 2>/dev/null; then
        echo "[entrypoint] database is up (after ${i}s)"
        break
    fi
    if [ "$i" -eq 90 ]; then
        echo "[entrypoint] WARNING: DB not reachable after 90s; starting Apache anyway" >&2
        echo "[entrypoint] retrying once to show the error:" >&2
        probe || true
    fi
    sleep 1
done

# Apache::DBI connects lazily per request, so Apache can start regardless.
. /etc/apache2/envvars
exec apache2 -D FOREGROUND
