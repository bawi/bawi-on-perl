#!/bin/sh
# Convenience wrapper: (re)seed the test DB with deterministic synthetic data.
# Run from the repo root on the host. Requires the stack to be up.
#   ./seed/reseed.sh
# Works with both `docker compose` (v2) and legacy `docker-compose`.
set -e
cd "$(dirname "$0")/.."
if docker compose version >/dev/null 2>&1; then
    docker compose exec -T web perl /home/bawi/bawi-spring/seed/seed.pl
else
    docker-compose exec -T web perl /home/bawi/bawi-spring/seed/seed.pl
fi
