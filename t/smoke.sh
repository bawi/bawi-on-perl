#!/bin/sh
# =============================================================================
# bawi-on-perl smoke test -- run against the LOCAL docker test stack.
#
#   docker compose up -d --build && ./seed/reseed.sh && sh t/smoke.sh
#   (the script waits for the web container itself, so up + seed + run works)
#
# Tiers:
#   0  compile every *.cgi and *.pl entry point in the script dirs (five
#      web-mapped: admin board main user reg, plus postman's mail-pipe
#      scripts; search/ is a non-web-mapped "Closed." placeholder and
#      */skin/* holds .cgi-NAMED HTML templates -- both excluded) plus
#      lib/**/*.pm; run t/markdown_smoke.pl
#   1  stack/schema: DB reachable, migration ledger complete, db-test.cgi
#   2  golden path over HTTP: login, list, read (plain + markdown render
#      cache), post, comment, logout
#   3  privacy canaries: the closed-board article and the private note are
#      served to who they belong to and to NOBODY else (logged-out,
#      non-member, wrong member) -- including the front page, where the
#      REAL stat crons are run against an engagement-qualifying closed
#      canary (only the m_read filter keeps it out) with an open control
#      article proving the channel live. Seeded by seed/seed.pl ("privacy
#      canaries"); tokens: article BODY carries CANARY-ARTICLE-*, article
#      TITLE carries CANARY-TITLE-* (title-rendering surfaces are a separate
#      leak channel from body-rendering ones).
#
# Conventions: POSIX sh + curl + docker compose only. fetch/login mutate
# current-shell state ($CODE, $JAR) and abort via fail() -- call them bare,
# NEVER inside $(...) (a subshell would swallow both). db/has are
# subshell-safe. The response body always lands in $TMP/body. Every check
# prints "ok N ..." or dies with "FAIL ..."; the run only passes if exactly
# $EXPECTED checks ran. Exit 0 = all green. Do NOT overlap runs (or a
# reseed) on one stack: reseed TRUNCATEs mid-suite, and two runs race the
# app's one-live-session-per-user rule.
# =============================================================================
set -u
cd "$(dirname "$0")/.."

EXPECTED=24
PASS='test1234'
CANARY_ARTICLE='CANARY-ARTICLE-b7a2f9'
CANARY_TITLE='CANARY-TITLE-c7d4e2'
CANARY_NOTE='CANARY-NOTE-n5c3e1'
CANARY_CONTROL='CONTROL-HOT-a9d2c4'

# Port: compose reads the gitignored .env; a shell running this script does
# not. Resolve like compose (env var wins, then .env, then 8080) so HTTP
# and `compose exec` target the same stack -- assuming .env is unchanged
# since `docker compose up`. Tolerate the common dotenv shapes (export
# prefix, quotes, CRLF) and refuse anything non-numeric rather than
# silently targeting the wrong port.
if [ -z "${BAWI_HTTP_PORT:-}" ] && [ -f .env ]; then
    BAWI_HTTP_PORT=$(sed -n 's/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}BAWI_HTTP_PORT=//p' .env | tail -1 | tr -d '"\r' | tr -d "'")
fi
case "${BAWI_HTTP_PORT:-8080}" in
    *[!0-9]*) echo "FAIL: unparseable BAWI_HTTP_PORT: '${BAWI_HTTP_PORT}'" >&2; exit 1 ;;
esac
BASE="http://localhost:${BAWI_HTTP_PORT:-8080}"

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

N=0
ok()   { N=$((N+1)); echo "ok $N  $*"; }
fail() {
    echo "FAIL: $*" >&2
    echo "---- last HTTP code: ${CODE:-none}" >&2
    if [ -s "${TMP:-}/body" ]; then
        echo "---- first bytes of last body:" >&2
        head -c 2000 "$TMP/body" >&2; echo >&2
    else
        echo "---- (last body empty)" >&2
    fi
    exit 1
}

TMP="${TMPDIR:-/tmp}/bawi-smoke.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# --- helpers -----------------------------------------------------------------
# fetch <jar|-> <url> [curl args...] -> body in $TMP/body, HTTP code in $CODE.
# Stateful: current shell only (see header).
fetch() {
    _jar=$1; _url=$2; shift 2
    if [ "$_jar" = "-" ]; then
        CODE=$(curl -sS -o "$TMP/body" -w '%{http_code}' "$@" "$_url") || fail "curl $_url"
    else
        CODE=$(curl -sS -b "$_jar" -c "$_jar" -o "$TMP/body" -w '%{http_code}' "$@" "$_url") || fail "curl $_url"
    fi
}
has() { grep -q "$1" "$TMP/body"; }   # case-sensitive; subshell-safe

# db <sql> -> rows on stdout. Credentials come from the db container's OWN
# env (the variables that created the account -- correct by construction, and
# no fifth copy of the tuple docker-compose.yml enumerates). On error the
# TRUE cause prints here (2>&1: some compose versions merge exec streams) --
# but fail()'s exit dies inside the caller's $(...) subshell, so every call
# site MUST append `|| exit 1` or the downstream check misdiagnoses.
db() {
    _out=$($DC exec -T db sh -c 'exec mariadb -N -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "$1" 2>&1' dbq "$1") \
        || fail "db query failed: $1 -- $_out"
    printf '%s\n' "$_out"
}

# login <id> -> jar at $TMP/<id>.jar in $JAR. Stateful: current shell only.
# NOTE: logging a user in expires that user's previous session (one live
# session per user) -- sessions of OTHER users are untouched.
login() {
    _id=$1; JAR="$TMP/$_id.jar"; : > "$JAR"
    fetch "$JAR" "$BASE/main/login.cgi" -d "id=$_id&passwd=$PASS"
    [ "$CODE" = "302" ] || fail "login $_id: expected 302, got $CODE"
    grep -q bawi_session "$JAR" || fail "login $_id: no bawi_session cookie"
}

# --- wait for the web container (owned here, not by the CI workflow, so a
# --- local run against a still-warming stack fails with the right message)
i=0
until [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/" || true)" = "200" ]; do
    i=$((i+1))
    [ "$i" -ge 60 ] && { echo "FAIL: web never became ready at $BASE" >&2; exit 1; }
    sleep 5
done

# ============================================================= tier 0: compile
# cd per script: the CGIs resolve modules cwd-relatively ("use lib '../lib'").
# Sweep counts are asserted -- a renamed dir must not shrink the sweep silently.
$DC exec -T web sh -c '
    cd /home/bawi/bawi-spring || exit 1
    rc=0; n=0
    for f in $(find admin board main user reg postman \( -name "*.cgi" -o -name "*.pl" \) -not -path "*/skin/*") ; do
        d=$(dirname "$f"); b=$(basename "$f"); n=$((n+1))
        out=$( cd "$d" && perl -c "$b" 2>&1 ) || { echo "compile FAIL: $f"; echo "$out"; rc=1; }
    done
    [ "$n" -ge 105 ] || { echo "compile sweep found only $n entry points (dir renamed?)"; rc=1; }
    m=0
    for f in $(find lib -name "*.pm") ; do
        m=$((m+1))
        out=$( perl -Ilib -c "$f" 2>&1 ) || { echo "compile FAIL: $f"; echo "$out"; rc=1; }
    done
    [ "$m" -ge 20 ] || { echo "compile sweep found only $m modules (lib/ moved?)"; rc=1; }
    echo "swept $n entry points + $m modules"
    exit $rc
' || fail "perl -c compile sweep"
ok "every entry point and module compiles"

# markdown_smoke self-calibrates its DoS-tripwire time bounds to the host
# (BAWI_SMOKE_TIME_FACTOR overrides; correctness asserts are never scaled).
$DC exec -T ${BAWI_SMOKE_TIME_FACTOR:+-e BAWI_SMOKE_TIME_FACTOR="$BAWI_SMOKE_TIME_FACTOR"} \
    web perl /home/bawi/bawi-spring/t/markdown_smoke.pl >/dev/null \
    || fail "t/markdown_smoke.pl"
ok "markdown/sanitization suite passes"

# ======================================================= tier 1: stack/schema
[ "$(db 'SELECT 1')" = "1" ] || fail "DB probe returned unexpected output"
ok "test DB reachable with container credentials"

for f in db/2*.sql; do
    m=$(basename "$f")
    got=$(db "SELECT COUNT(*) FROM schema_migrations WHERE filename='$m'") || exit 1
    [ "$got" = "1" ] || fail "migration not in ledger: $m (got '$got')"
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

aid=$(db "SELECT MIN(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
[ -n "$aid" ] && [ "$aid" != "NULL" ] || fail "no seeded article on board 2 (got '$aid')"
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$aid"
[ "$CODE" = "200" ] || fail "read bid=2 aid=$aid: HTTP $CODE"
has "자유게시판" || fail "read: board title missing"
ok "read an open-board article"

# markdown render path: category=1 article -> Bawi::Markdown via
# Board.pm format_article -> bw_xboard_body_html read-through cache
# (INSTALLATION.md checklist item 7).
maid=$(db "SELECT MIN(article_id) FROM bw_xboard_header WHERE board_id=2 AND category=1") || exit 1
[ -n "$maid" ] && [ "$maid" != "NULL" ] || fail "no seeded markdown article on board 2"
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$maid"
[ "$CODE" = "200" ] || fail "markdown read: HTTP $CODE"
has "<h2" || fail "markdown article did not render HTML"
got=$(db "SELECT COUNT(*) FROM bw_xboard_body_html WHERE article_id=$maid") || exit 1
[ "$got" = "1" ] || fail "markdown render cache row not created (got '$got')"
ok "markdown article renders and populates the body_html cache"

marker="smoke-post-$$"
fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "title=smoke test article" \
      --data-urlencode "body=posted by t/smoke.sh $marker"
[ "$CODE" = "302" ] || fail "write: expected 302 redirect, got $CODE"
newaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
[ -n "$newaid" ] && [ "$newaid" != "NULL" ] || fail "post: no article found after write"
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$newaid"
has "$marker" || fail "posted article not readable back"
ok "post an article and read it back"

fetch "$J2" "$BASE/board/comment.cgi" \
      --data-urlencode "action=add" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$newaid" \
      --data-urlencode "body=smoke comment $marker"
[ "$CODE" = "302" ] || [ "$CODE" = "200" ] || fail "comment: HTTP $CODE"
got=$(db "SELECT COUNT(*) FROM bw_xboard_comment WHERE article_id=$newaid") || exit 1
[ "$got" = "1" ] || fail "comment row not created (got '$got')"
ok "post a comment"

fetch "$J2" "$BASE/main/logout.cgi"
fetch "$J2" "$BASE/board/index.cgi"
# Discriminator, not a string grep: logged-out board/index.cgi is a 302
# redirect to the login page (Auth::login_page); a live session gets 200.
# (A body grep for "passwd|login" matches BOTH outcomes: the member menu
# links passwd.cgi, and Apache's canned 302 body echoes the login URL.)
[ "$CODE" = "302" ] || fail "logout: board index gave HTTP $CODE, session still valid"
ok "logout invalidates the session (302 to login)"

# ==================================================== tier 3: privacy canaries
cbid=$(db "SELECT board_id FROM bw_xboard_board WHERE keyword='secret'") || exit 1
[ -n "$cbid" ] && [ "$cbid" != "NULL" ] || fail "canary board not seeded (keyword 'secret')"
caid=$(db "SELECT article_id FROM bw_xboard_header WHERE board_id=$cbid LIMIT 1") || exit 1
[ -n "$caid" ] && [ "$caid" != "NULL" ] || fail "canary article not seeded (board $cbid)"
ok "canary board ($cbid) and article ($caid) present"

# positive control first: a closed-group MEMBER (tester03 -- member uid 2..6,
# NOT the board owner, so this exercises the group-membership grant, not the
# owner bypass) sees body and title tokens.
login tester03; J3=$JAR
fetch "$J3" "$BASE/board/read.cgi?bid=$cbid&aid=$caid"
[ "$CODE" = "200" ] || fail "member read of canary: HTTP $CODE"
has "$CANARY_ARTICLE" || fail "member tester03 cannot read the canary body (test would be vacuous)"
has "$CANARY_TITLE"   || fail "member tester03 does not see the canary title (test would be vacuous)"
ok "canary readable by a non-owner group member (positive control)"

# logged-out: never a token. With AllowAnonAccess=1 (this stack AND the
# conf samples) board CGIs serve anonymous visitors a 200 page SHELL and let
# authz suppress the article; with AllowAnonAccess=0 they 302 to login.
# Either status is policy -- the privacy property is the absent tokens.
# (Note: the shell does expose the closed BOARD's name to anonymous
# visitors -- board existence, not content; see PR #32 discussion.)
fetch - "$BASE/board/read.cgi?bid=$cbid&aid=$caid"
[ "$CODE" = "200" ] || [ "$CODE" = "302" ] || fail "logged-out canary read: HTTP $CODE"
has "$CANARY_ARTICLE" && fail "LEAK: canary body served logged-out"
has "$CANARY_TITLE"   && fail "LEAK: canary title served logged-out"
ok "canary not served logged-out"

# wrong member (tester07 is not in gid 3): never. This is THE member-to-member
# leak assertion.
login tester07; J7=$JAR
fetch "$J7" "$BASE/board/read.cgi?bid=$cbid&aid=$caid"
[ "$CODE" = "200" ] || fail "non-member canary read: HTTP $CODE"
has "$CANARY_ARTICLE" && fail "LEAK: canary body served to non-member tester07"
has "$CANARY_TITLE"   && fail "LEAK: canary title served to non-member tester07 on read.cgi"
ok "canary not served to a logged-in non-member"

# non-member must not be able to write into the closed board either.
fetch "$J7" "$BASE/board/write.cgi" \
      --data-urlencode "bid=$cbid" \
      --data-urlencode "title=should-not-land" \
      --data-urlencode "body=intrusion-$$"
got=$(db "SELECT COUNT(*) FROM bw_xboard_header WHERE board_id=$cbid AND title='should-not-land'") || exit 1
[ "$got" = "0" ] || fail "LEAK: non-member wrote into the closed board (got '$got')"
ok "non-member cannot post into the closed board"

# Front-page channels, tested LIVE end to end. The closed canary article
# carries qualifying engagement (recom 5, count 50, created within the hot
# window -- see seed.pl), so when we run the REAL stat populators below,
# only their new m_read=1 filter keeps it out of the feeder tables; the
# open control article (same engagement + CANARY_CONTROL body token) MUST
# come through, proving the cron and the hot teaser are actually live --
# no assertion here can pass vacuously.
ctrlaid=$(db "SELECT article_id FROM bw_xboard_body WHERE body LIKE '%$CANARY_CONTROL%' LIMIT 1") || exit 1
[ -n "$ctrlaid" ] && [ "$ctrlaid" != "NULL" ] || fail "hot-control article not seeded"
# SQL passed as an argument, not stdin: `compose exec < file` hangs on some
# compose versions (v2.0.0-beta.4 measured); the -e argv path is the same
# shape db() uses and works everywhere. mariadb -e runs multi-statement.
db "$(cat main/sql/update_article_stat.sql)" >/dev/null \
    || fail "update_article_stat.sql failed against the seeded DB"
db "$(cat main/sql/update_xboard_stat.sql)" >/dev/null \
    || fail "update_xboard_stat.sql failed against the seeded DB"
got=$(db "SELECT COUNT(*) FROM bw_xboard_stat_article WHERE article_id=$ctrlaid") || exit 1
[ "$got" = "1" ] || fail "open control did not enter stat_article -- cron test is vacuous (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_xboard_stat_article WHERE board_id=$cbid") || exit 1
[ "$got" = "0" ] || fail "LEAK: engaged closed-board article entered stat_article through the cron"
got=$(db "SELECT COUNT(*) FROM bw_xboard_stat_board WHERE board_id=$cbid") || exit 1
[ "$got" = "0" ] || fail "LEAK: closed board entered stat_board through the cron"
ok "stat crons admit the control and exclude the closed board (live)"

# window pin: keeps the title assertions below non-vacuous (the canary must
# still be within news.cgi's 40-newest \$recent window to be assertable).
newer=$(db "SELECT COUNT(*) FROM bw_xboard_header WHERE article_id > $caid") || exit 1
[ "$newer" -lt 40 ] || fail "canary fell off the 40-newest list ($newer newer articles) -- stale stack: reseed and re-run"
fetch "$J7" "$BASE/main/news.cgi"
[ "$CODE" = "200" ] || fail "news.cgi: HTTP $CODE"
has "자유게시판" || fail "news.cgi recent list not rendering seeded data (liveness)"
has "$CANARY_CONTROL" || fail "hot teaser not serving the open control body (channel vacuous)"
has "$CANARY_TITLE" && fail "LEAK: closed-board title served on the front page"
has "$CANARY_ARTICLE" && fail "LEAK: closed-board body served on the front page"
ok "front page: hot teaser live; closed board fully absent (titles + bodies)"

# private note: recipient inbox and sender sent-box see it; nobody else.
login tester02; J2=$JAR
fetch "$J2" "$BASE/main/note.cgi"
[ "$CODE" = "200" ] || fail "note inbox tester02: HTTP $CODE"
has "$CANARY_NOTE" || fail "recipient tester02 cannot see the canary note (vacuous)"
ok "canary note visible in the recipient's inbox (positive control)"

# J3 (logged in above) is still live: sessions expire per-user on login, and
# nothing re-logged tester03 since.
fetch "$J3" "$BASE/main/note.cgi?mbox=sent"
[ "$CODE" = "200" ] || fail "note sent-box tester03: HTTP $CODE"
has "$CANARY_NOTE" || fail "sender tester03 cannot see the canary note in the sent box (vacuous)"
ok "canary note visible in the sender's sent box (positive control)"

login tester04; J4=$JAR
fetch "$J4" "$BASE/main/note.cgi"
[ "$CODE" = "200" ] || fail "note inbox tester04: HTTP $CODE"
has "$CANARY_NOTE" && fail "LEAK: canary note served to tester04"
ok "canary note not served to another member"

fetch - "$BASE/main/note.cgi"
[ "$CODE" = "302" ] || fail "logged-out note.cgi: expected 302, got $CODE"
has "$CANARY_NOTE" && fail "LEAK: canary note served logged-out"
ok "canary note not served logged-out"

[ "$N" -eq "$EXPECTED" ] || fail "ran $N of $EXPECTED checks -- a check was skipped or removed without updating EXPECTED"
echo "all $N checks passed"
