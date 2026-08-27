#!/bin/sh
# =============================================================================
# bawi-on-perl smoke test -- run against the LOCAL docker test stack.
#
#   ./t/smoke.sh          # stack must be up and freshly seeded:
#                         #   docker compose up -d --build && ./seed/reseed.sh
#
# Tiers:
#   0  compile every *.cgi and lib/**/*.pm inside the web container,
#      run t/markdown_smoke.pl (sanitization suite + drift guards)
#   1  stack/schema: migration ledger complete, db-test.cgi serves
#   2  golden path over HTTP: login, list, read, post, comment, logout
#   3  privacy canaries: the closed-board article and the private note are
#      served to their owners and to NOBODY else (logged-out, non-member,
#      wrong member, front page). Seeded by seed/seed.pl ("privacy canaries").
#
# Conventions: POSIX sh + curl + docker compose only. fetch/login run in the
# CURRENT shell (no command substitution: $CODE and fail() must propagate);
# the response body always lands in $TMP/body. Every check prints "ok N ..."
# or dies with "FAIL ...". Exit 0 = all green.
# =============================================================================
set -u
cd "$(dirname "$0")/.."

BASE="http://localhost:${BAWI_HTTP_PORT:-8080}"
PASS='test1234'
CANARY_ARTICLE='CANARY-ARTICLE-b7a2f9'
CANARY_NOTE='CANARY-NOTE-n5c3e1'

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

N=0
ok()   { N=$((N+1)); echo "ok $N  $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

TMP="${TMPDIR:-/tmp}/bawi-smoke.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# --- helpers (call in the current shell, never in $(...)) --------------------
# fetch <jar|-> <url> [curl args...] -> body in $TMP/body, HTTP code in $CODE
fetch() {
    _jar=$1; _url=$2; shift 2
    if [ "$_jar" = "-" ]; then
        CODE=$(curl -sS -o "$TMP/body" -w '%{http_code}' "$@" "$_url") || fail "curl $_url"
    else
        CODE=$(curl -sS -b "$_jar" -c "$_jar" -o "$TMP/body" -w '%{http_code}' "$@" "$_url") || fail "curl $_url"
    fi
}
has()    { grep -q "$1" "$TMP/body"; }
db() { $DC exec -T db mariadb -N -u bawi_test -pbawi-local-test-pw bawi -e "$1" 2>/dev/null; }

# login <id> -> jar at $TMP/<id>.jar (NOTE: logging a user in expires that
# user's previous session -- keep at most one live jar per user).
login() {
    _id=$1; JAR="$TMP/$_id.jar"; : > "$JAR"
    fetch "$JAR" "$BASE/main/login.cgi" -d "id=$_id&passwd=$PASS"
    [ "$CODE" = "302" ] || fail "login $_id: expected 302, got $CODE"
    grep -q bawi_session "$JAR" || fail "login $_id: no bawi_session cookie"
}

# ============================================================= tier 0: compile
$DC exec -T web sh -c '
    cd /home/bawi/bawi-spring || exit 1
    rc=0
    # */skin/* holds .cgi-named HTML templates, not executed Perl (Apache
    # only executes the script directories) -- exclude them from the sweep.
    for f in $(find admin board main user reg postman -name "*.cgi" -not -path "*/skin/*") ; do
        d=$(dirname "$f"); b=$(basename "$f")
        out=$( cd "$d" && perl -c "$b" 2>&1 ) || { echo "compile FAIL: $f"; echo "$out"; rc=1; }
    done
    for m in $(find lib -name "*.pm") ; do
        out=$( perl -Ilib -c "$m" 2>&1 ) || { echo "compile FAIL: $m"; echo "$out"; rc=1; }
    done
    exit $rc
' || fail "perl -c compile sweep"
ok "every *.cgi and lib/**/*.pm compiles"

$DC exec -T web perl /home/bawi/bawi-spring/t/markdown_smoke.pl >/dev/null \
    || fail "t/markdown_smoke.pl"
ok "markdown/sanitization suite passes"

# ======================================================= tier 1: stack/schema
# Every repo migration must be recorded in the ledger (fresh-DB apply worked).
for f in db/2*.sql; do
    m=$(basename "$f")
    got=$(db "SELECT COUNT(*) FROM schema_migrations WHERE filename='$m'")
    [ "$got" = "1" ] || fail "migration not in ledger: $m"
done
ok "all $(ls db/2*.sql | wc -l | tr -d ' ') migrations recorded in schema_migrations"

fetch - "$BASE/main/db-test.cgi"
[ "$CODE" = "200" ] || fail "db-test.cgi: HTTP $CODE"
has "before query" || fail "db-test.cgi: missing marker output"
ok "db-test.cgi serves and reaches the DB"

# ======================================================== tier 2: golden path
fetch - "$BASE/"
[ "$CODE" = "200" ] || fail "front page: HTTP $CODE"
ok "front page serves (login gate)"

login tester02; J2=$JAR
ok "login tester02 -> 302 + session cookie"

fetch "$J2" "$BASE/board/index.cgi"
[ "$CODE" = "200" ] || fail "board index: HTTP $CODE"
ok "board index serves for a member"

aid=$(db "SELECT MIN(article_id) FROM bw_xboard_header WHERE board_id=2")
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$aid"
[ "$CODE" = "200" ] || fail "read bid=2 aid=$aid: HTTP $CODE"
has "자유게시판" || fail "read: board title missing"
ok "read an open-board article"

marker="smoke-post-$$"
fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "title=smoke test article" \
      --data-urlencode "body=posted by t/smoke.sh $marker"
[ "$CODE" = "302" ] || fail "write: expected 302 redirect, got $CODE"
newaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2")
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$newaid"
has "$marker" || fail "posted article not readable back"
ok "post an article and read it back"

fetch "$J2" "$BASE/board/comment.cgi" \
      --data-urlencode "action=add" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$newaid" \
      --data-urlencode "body=smoke comment $marker"
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || fail "comment: HTTP $CODE"
got=$(db "SELECT COUNT(*) FROM bw_xboard_comment WHERE article_id=$newaid")
[ "$got" = "1" ] || fail "comment row not created (got $got)"
ok "post a comment"

fetch "$J2" "$BASE/main/logout.cgi"
fetch "$J2" "$BASE/board/index.cgi"
grep -qi "passwd\|login" "$TMP/body" || fail "logout: session still valid"
ok "logout invalidates the session"

# ==================================================== tier 3: privacy canaries
caid=$(db "SELECT article_id FROM bw_xboard_header WHERE board_id=7 LIMIT 1")
[ -n "$caid" ] || fail "canary article not seeded (board 7)"

# positive control first: a closed-group member DOES see the canary.
login tester02; J2=$JAR
fetch "$J2" "$BASE/board/read.cgi?bid=7&aid=$caid"
has "$CANARY_ARTICLE" || fail "member tester02 cannot read the canary (test would be vacuous)"
ok "closed-board canary readable by its group member (positive control)"

# logged-out: never.
fetch - "$BASE/board/read.cgi?bid=7&aid=$caid"
has "$CANARY_ARTICLE" && fail "LEAK: canary served logged-out"
ok "canary not served logged-out"

# wrong member (tester07 is not in gid 3): never. This is THE member-to-member
# leak assertion.
login tester07; J7=$JAR
fetch "$J7" "$BASE/board/read.cgi?bid=7&aid=$caid"
has "$CANARY_ARTICLE" && fail "LEAK: canary served to non-member tester07"
ok "canary not served to a logged-in non-member"

# non-member must not be able to write into the closed board either.
fetch "$J7" "$BASE/board/write.cgi" \
      --data-urlencode "bid=7" \
      --data-urlencode "title=should-not-land" \
      --data-urlencode "body=intrusion-$$"
got=$(db "SELECT COUNT(*) FROM bw_xboard_header WHERE board_id=7 AND title='should-not-land'")
[ "$got" = "0" ] || fail "LEAK: non-member wrote into the closed board"
ok "non-member cannot post into the closed board"

# front page must never teaser the closed board (hot query has no perm filter;
# this pins the current safe behavior -- see PR discussion).
fetch "$J7" "$BASE/main/news.cgi"
has "$CANARY_ARTICLE" && fail "LEAK: canary teaser on front page"
ok "canary absent from the front page"

# private note: recipient sees it, anyone else does not.
fetch "$J2" "$BASE/main/note.cgi"
has "$CANARY_NOTE" || fail "recipient tester02 cannot see the canary note (vacuous)"
ok "canary note visible to its recipient (positive control)"

login tester04; J4=$JAR
fetch "$J4" "$BASE/main/note.cgi"
has "$CANARY_NOTE" && fail "LEAK: canary note served to tester04"
ok "canary note not served to another member"

fetch - "$BASE/main/note.cgi"
has "$CANARY_NOTE" && fail "LEAK: canary note served logged-out"
ok "canary note not served logged-out"

echo "all $N checks passed"
