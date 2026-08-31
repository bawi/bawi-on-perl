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
#   4  mention notes: @id -> bw_note lifecycle (both producers, self-
#      silence, sent box until Save, grace-window retraction sparing
#      saved + sibling + unrelated notes, manual unsend) + profile-link
#      rendering and the anonboard negative
#   5  attachments: upload -> detach round-trip (row/file/link), the
#      ghost-row detach (file missing must not keep the row), and the
#      ghost-image counter balance
#   6  polls: write-in (uopt) polls save with 1 or 0 seed options, the
#      vote creates the option once (dedup) recording every answer, the
#      0-seed poll renders without a phantom option row, and a fixed
#      poll keeps a literal "0" seed option
#   7  poll cross-tabs: the read page links to poll.cgi, an unvoted
#      viewer gets the gated message (not silence), the poll x poll
#      matrix renders, the <3 whole-table suppression still fires, and
#      the poll x ki axis adaptively merges sparse cohorts into bands --
#      dense cohorts standing alone (multi-band render), a sparse
#      single band suppressing instead of publishing, and a 1-2 voter
#      ki-less remainder suppressing (the subtraction guard)
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

EXPECTED=57
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

# db-test.cgi DB diagnostic -> members only (PR #34); its board-title
# dump is gone too (it enumerated closed boards to any member).
fetch - "$BASE/main/db-test.cgi"
[ "$CODE" = "302" ] || fail "unauthenticated db-test.cgi: expected 302, got $CODE"
ok "db-test.cgi requires login"

# ======================================================== tier 2: golden path
fetch - "$BASE/"
[ "$CODE" = "200" ] || fail "front page: HTTP $CODE"
ok "front page serves (login gate)"

login tester02; J2=$JAR
ok "login tester02 -> 302 + session cookie"

fetch "$J2" "$BASE/board/index.cgi"
[ "$CODE" = "200" ] || fail "board index: HTTP $CODE"
ok "board index serves for a member"

fetch "$J2" "$BASE/main/db-test.cgi"
[ "$CODE" = "200" ] || fail "authed db-test.cgi: HTTP $CODE"
has "before query" || fail "db-test.cgi: missing marker output"
ok "db-test.cgi serves its diagnostics to a member"

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

# logged-out: boards that grant guests no action bounce anonymous visitors
# BEFORE any board data is emitted (PR #34) -- even the shell used to leak
# the board name, group name, and owner name/id. The guard is per-action
# (read: a_read; write: +a_write; comment: +a_comment; is_anonboard grants
# nothing -- it only masks author identity). Assert the redirect AND the
# absence of every leaked string, in every guarded CGI, from both
# directions: closed surfaces bounce, the a_read=1 notice board and the
# a_write=1 drop-box still serve guests.
# NB: the group name is a prefix of the board name -- keep the board-name
# check first so a board-name leak is attributed correctly.
fetch - "$BASE/board/read.cgi?bid=$cbid&aid=$caid"
[ "$CODE" = "302" ] || fail "logged-out closed-board read: expected 302, got $CODE"
has "$CANARY_ARTICLE" && fail "LEAK: canary body served logged-out"
has "$CANARY_TITLE"   && fail "LEAK: canary title served logged-out"
has "비공개 테스트판"  && fail "LEAK: closed board NAME in the anonymous response"
has "비공개 테스트"    && fail "LEAK: closed GROUP name in the anonymous response"
has "tester02"        && fail "LEAK: closed board OWNER id in the anonymous response"
has "테스트유저02"     && fail "LEAK: closed board OWNER name in the anonymous response"
ok "closed-board shell not served logged-out (name/group/owner hidden)"

naid=$(db "SELECT MIN(article_id) FROM bw_xboard_header WHERE board_id=1") || exit 1
[ -n "$naid" ] && [ "$naid" != "NULL" ] || fail "no seeded article on the notice board"
fetch - "$BASE/board/read.cgi?bid=1&aid=$naid"
[ "$CODE" = "200" ] || fail "guest read of the a_read=1 notice board: HTTP $CODE (guard over-blocked)"
has "공지사항" || fail "notice board not rendering for a guest"
ok "public notice board still serves guests (guard does not over-block)"

# each action CGI carries its own copy of the guard -- pin every copy
# against the closed board.
fetch - "$BASE/board/write.cgi?bid=$cbid"
[ "$CODE" = "302" ] || fail "logged-out closed-board write form: expected 302, got $CODE"
has "비공개 테스트판" && fail "LEAK: closed board NAME on anonymous write.cgi"
ok "write.cgi bounces logged-out visitors off the closed board"

fetch - "$BASE/board/comment.cgi?bid=$cbid&aid=$caid"
[ "$CODE" = "302" ] || fail "logged-out closed-board comment.cgi: expected 302, got $CODE"
ok "comment.cgi bounces logged-out visitors off the closed board"

# commentx.cgi is retired (nothing ever linked it; its actions were dead
# since the svn import) -- the placeholder must serve no board data
fetch - "$BASE/board/commentx.cgi?bid=$cbid&aid=$caid"
[ "$CODE" = "200" ] || fail "retired commentx.cgi: HTTP $CODE"
has 'Closed\.' || fail "commentx.cgi placeholder body missing"
has "Content-type:" && fail "raw CGI header leaked into the placeholder body (ParseHeaders is off on this vhost)"
ct=$(curl -sS -o /dev/null -w '%{content_type}' "$BASE/board/commentx.cgi?bid=$cbid&aid=$caid") || fail "curl (content-type probe) commentx.cgi"
case "$ct" in text/plain*) ;; *) fail "retired commentx.cgi content-type: '$ct' (expected text/plain)";; esac
has "비공개 테스트판" && fail "LEAK: closed board NAME from retired commentx.cgi"
ok "commentx.cgi retired: serves only the Closed placeholder"

# members-only anonboard: is_anonboard masks author identity, it must NOT
# admit guests (the PR #34 review regression: an earlier guard draft
# exempted it).
anbid=$(db "SELECT board_id FROM bw_xboard_board WHERE is_anonboard=1 AND a_read=0 ORDER BY board_id LIMIT 1") || exit 1
[ -n "$anbid" ] && [ "$anbid" != "NULL" ] || fail "no seeded members-only anonboard"
fetch - "$BASE/board/read.cgi?bid=$anbid"
[ "$CODE" = "302" ] || fail "logged-out members-only anonboard read: expected 302, got $CODE"
has "익명 비공개판" && fail "LEAK: members-only anonboard NAME in the anonymous response"
ok "members-only anonboard shell not served logged-out"

# guest drop-box (a_write=1, a_read=0): the write form must still serve
# guests -- the over-block direction of the per-action predicate.
dbbid=$(db "SELECT board_id FROM bw_xboard_board WHERE a_write=1 AND a_read=0 LIMIT 1") || exit 1
[ -n "$dbbid" ] && [ "$dbbid" != "NULL" ] || fail "no seeded guest drop-box board"
fetch - "$BASE/board/write.cgi?bid=$dbbid"
[ "$CODE" = "200" ] || fail "guest write form on the a_write=1 drop-box: HTTP $CODE (guard over-blocked)"
has "건의함" || fail "drop-box write form not rendering for a guest"
ok "guest drop-box still serves its write form logged-out"

# thumbnails are board content: an anonymous atid probe of a closed-board
# attachment must bounce (PR #34; full files were already gated by
# attach.cgi). The seeded row has no file on disk -- the gate fires on the
# row's board before the bytes matter.
catid=$(db "SELECT MIN(attach_id) FROM bw_xboard_attach WHERE board_id=$cbid") || exit 1
[ -n "$catid" ] && [ "$catid" != "NULL" ] || fail "no seeded attachment row on the canary board"
fetch - "$BASE/board/thumb.cgi?atid=$catid"
[ "$CODE" = "302" ] || fail "logged-out closed-board thumbnail: expected 302, got $CODE"
ok "thumb.cgi bounces logged-out visitors off closed-board attachments"

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

# ======================================================== tier 4: mention notes
# @id in an authored comment sends the mentioned user a note (bw_note).
# Lifecycle contract under test:
#   - self-mentions are silent; anonboards neither notify nor linkify
#   - the note sits in the sender's sent box until the recipient SAVES it
#     (read_time is a save timestamp, not a read receipt: only the
#     explicit Save action sets it; merely reading the inbox does not)
#   - deleting the comment inside its 1-minute grace window retracts
#     UNSAVED mention notes, spares saved ones, and touches only that
#     comment's notes (best-effort retraction, not history rewriting)
#   - the sender can manually unsend an unsaved mention note from the
#     sent box like any other note (delete_msg has no origin special-case)
# All note counts are scoped to the fresh article's aid so seeded notes
# (e.g. the tier-3 canary) can never satisfy or pollute a check.
# Both producers are exercised: comment.cgi (#c tail) and write.cgi (the
# anchor-less article variant, via the host article's own @mention).
# Variables are named by role (saved/self/pin/keep/retract/unsend).
login tester02; J2=$JAR
login tester05; J5=$JAR   # recipient jar up front, outside any grace window

# grace_guard <cid>: the app hard-deletes only comments younger than 60s.
# If the harness itself burned that budget getting here, name the clock,
# not the app (cf. BAWI_SMOKE_TIME_FACTOR for the same host-speed concern).
grace_guard() {
    _g=$(db "SELECT created > NOW() - INTERVAL 50 SECOND FROM bw_xboard_comment WHERE comment_id=$1") || exit 1
    [ "$_g" = "1" ] || fail "harness too slow: comment $1 aged past the grace window before its delete (overloaded host?) -- not an app regression"
}

fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "title=mention smoke article" \
      --data-urlencode "body=mention lifecycle host $$ cc @tester05"
[ "$CODE" = "302" ] || fail "mention: write host article: HTTP $CODE"
mnaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
[ -n "$mnaid" ] && [ "$mnaid" != "NULL" ] || fail "mention: host article not created"
# write.cgi producer: article mentions carry NO #c anchor (end-anchored tail)
got=$(db "SELECT COUNT(*) FROM bw_note WHERE to_id='tester05' AND from_id='tester02' AND read_time IS NULL AND msg LIKE '%aid=$mnaid'") || exit 1
[ "$got" = "1" ] || fail "article mention note not sent via write.cgi (got '$got')"
ok "article @mention sends an anchor-less note (write.cgi producer)"

# --- saved-note lifecycle: send -> sent box -> Save -> grace delete spares it
fetch "$J2" "$BASE/board/comment.cgi" \
      --data-urlencode "action=add" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$mnaid" \
      --data-urlencode "body=ping @tester05 mention-smoke-$$"
cid_saved=$(db "SELECT MAX(comment_id) FROM bw_xboard_comment WHERE article_id=$mnaid") || exit 1
[ -n "$cid_saved" ] && [ "$cid_saved" != "NULL" ] || fail "mention: comment not created"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE to_id='tester05' AND from_id='tester02' AND read_time IS NULL AND msg LIKE '%aid=$mnaid#c%'") || exit 1
[ "$got" = "1" ] || fail "mention note not sent (got '$got')"
msgid_saved=$(db "SELECT msg_id FROM bw_note WHERE to_id='tester05' AND from_id='tester02' AND msg LIKE '%aid=$mnaid#c%'") || exit 1
ok "@mention in a comment sends the mentioned user a note"

fetch "$J2" "$BASE/main/note.cgi?mbox=sent"
[ "$CODE" = "200" ] || fail "sender sent box: HTTP $CODE"
has "aid=$mnaid#c" || fail "unsaved mention note missing from the sender's sent box"
ok "mention note appears in the sender's sent box until saved"

# recipient saves it -> read_time set -> leaves the sender's sent box
fetch "$J5" "$BASE/main/note.cgi" -d "r_msg_id=$msgid_saved&action=Save"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE msg_id=$msgid_saved AND read_time IS NOT NULL") || exit 1
[ "$got" = "1" ] || fail "Save did not set read_time on the mention note (got '$got')"
fetch "$J2" "$BASE/main/note.cgi?mbox=sent"
[ "$CODE" = "200" ] || fail "sender sent box re-fetch: HTTP $CODE"
has "aid=$mnaid#c" && fail "saved mention note still listed in the sender's sent box"
ok "recipient's Save moves the note out of the sender's sent box"

# grace-window delete of the mentioning comment: the SAVED note survives
grace_guard "$cid_saved"
fetch "$J2" "$BASE/board/comment.cgi" -d "action=delete&bid=2&aid=$mnaid&cid=$cid_saved"
got=$(db "SELECT COUNT(*) FROM bw_xboard_comment WHERE comment_id=$cid_saved") || exit 1
[ "$got" = "0" ] || fail "grace-window delete left the comment row (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE msg_id=$msgid_saved") || exit 1
[ "$got" = "1" ] || fail "retraction deleted a SAVED note (got '$got')"
ok "grace-window delete spares the already-saved mention note"

# --- self-mention: no note; the comment itself must land (else vacuous)
fetch "$J2" "$BASE/board/comment.cgi" \
      --data-urlencode "action=add" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$mnaid" \
      --data-urlencode "body=note to self @tester02 mention-smoke-$$"
cid_self=$(db "SELECT MAX(comment_id) FROM bw_xboard_comment WHERE article_id=$mnaid") || exit 1
[ -n "$cid_self" ] && [ "$cid_self" != "NULL" ] || fail "self-mention comment did not land (check would be vacuous)"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE to_id='tester02' AND from_id='tester02' AND msg LIKE '%aid=$mnaid#c%'") || exit 1
[ "$got" = "0" ] || fail "self-mention produced a note (got '$got')"
ok "self-mention stays silent"

# --- unsaved note + grace delete: retracted, and ONLY that comment's note.
# Scope pin: an unrelated unsaved note from the same sender must survive
# (guards the WHERE clause against a future over-broad "simplification").
fetch "$J2" "$BASE/main/note.cgi" \
      --data-urlencode "to=tester05" \
      --data-urlencode "msg=unrelated scope pin $$"
pin_msgid=$(db "SELECT MAX(msg_id) FROM bw_note WHERE to_id='tester05' AND from_id='tester02' AND msg LIKE '%scope pin%'") || exit 1
[ -n "$pin_msgid" ] && [ "$pin_msgid" != "NULL" ] || fail "scope-pin note not sent"
# a sibling KEEP mention comment: its note must survive the retract --
# this pins the #c tail term of the DELETE, not just the [언급] prefix
fetch "$J2" "$BASE/board/comment.cgi" \
      --data-urlencode "action=add" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$mnaid" \
      --data-urlencode "body=keeper @tester05 mention-smoke-$$"
cid_keep=$(db "SELECT MAX(comment_id) FROM bw_xboard_comment WHERE article_id=$mnaid") || exit 1
[ -n "$cid_keep" ] && [ "$cid_keep" != "NULL" ] && [ "$cid_keep" -gt "$cid_self" ] || fail "keeper comment not created"
cn_keep=$(db "SELECT comment_no FROM bw_xboard_comment WHERE comment_id=$cid_keep") || exit 1
fetch "$J2" "$BASE/board/comment.cgi" \
      --data-urlencode "action=add" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$mnaid" \
      --data-urlencode "body=again @tester05 mention-smoke-$$"
cid_retract=$(db "SELECT MAX(comment_id) FROM bw_xboard_comment WHERE article_id=$mnaid") || exit 1
got=$(db "SELECT COUNT(*) FROM bw_note WHERE to_id='tester05' AND read_time IS NULL AND msg LIKE '%aid=$mnaid#c%'") || exit 1
[ "$got" = "2" ] || fail "expected two unsaved comment-mention notes before the retract (got '$got')"
grace_guard "$cid_retract"
fetch "$J2" "$BASE/board/comment.cgi" -d "action=delete&bid=2&aid=$mnaid&cid=$cid_retract"
got=$(db "SELECT COUNT(*) FROM bw_xboard_comment WHERE comment_id=$cid_retract") || exit 1
[ "$got" = "0" ] || fail "grace-window delete left the comment row (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE to_id='tester05' AND read_time IS NULL AND msg LIKE '%aid=$mnaid#c$cn_keep'") || exit 1
[ "$got" = "1" ] || fail "sibling comment's note was retracted -- the #c tail term is not scoping (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE to_id='tester05' AND read_time IS NULL AND msg LIKE '%aid=$mnaid#c%'") || exit 1
[ "$got" = "1" ] || fail "retraction did not remove exactly one note (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE msg_id=$pin_msgid") || exit 1
[ "$got" = "1" ] || fail "retraction over-reached: unrelated note from the same sender deleted"
ok "grace-window delete retracts exactly its own comment's unsaved note"

# --- manual unsend from the sent box (the keeper's surviving note)
msgid_unsend=$(db "SELECT MAX(msg_id) FROM bw_note WHERE to_id='tester05' AND from_id='tester02' AND read_time IS NULL AND msg LIKE '%aid=$mnaid#c%'") || exit 1
[ -n "$msgid_unsend" ] && [ "$msgid_unsend" != "NULL" ] || fail "keeper mention note missing for the unsend check"
fetch "$J2" "$BASE/main/note.cgi" -d "r_msg_id=$msgid_unsend&action=Delete"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE msg_id=$msgid_unsend") || exit 1
[ "$got" = "0" ] || fail "sent-box Delete did not remove the mention note (got '$got')"
ok "sender can unsend an unsaved mention note from the sent box"

# --- rendered mention: @id links to the profile pop-up (note-compose stays
# one click away inside the profile header), never to note.cgi. The keeper
# comment and the host article body still carry @tester05 mentions.
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$mnaid"
[ "$CODE" = "200" ] || fail "mention render: read.cgi HTTP $CODE"
has 'profile.cgi?id=tester05">@tester05</a>' || fail "mention did not render as a profile link"
has "to_default=tester05" && fail "mention renders a note-compose link (tester05 authored nothing here)"
ok "rendered @mention links to the profile pop-up"

# --- anonboard: mentions must neither notify nor linkify there
anbid2=$(db "SELECT board_id FROM bw_xboard_board WHERE is_anonboard=1 AND a_read=0 ORDER BY board_id LIMIT 1") || exit 1
[ -n "$anbid2" ] && [ "$anbid2" != "NULL" ] || fail "no seeded anonboard for the mention check"
fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=$anbid2" \
      --data-urlencode "title=anon mention host" \
      --data-urlencode "body=anon ping @tester05 mention-smoke-$$"
[ "$CODE" = "302" ] || fail "anonboard write: HTTP $CODE"
anaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=$anbid2") || exit 1
[ -n "$anaid" ] && [ "$anaid" != "NULL" ] || fail "anonboard article not created (check would be vacuous)"
got=$(db "SELECT COUNT(*) FROM bw_note WHERE msg LIKE '%aid=$anaid'") || exit 1
[ "$got" = "0" ] || fail "anonboard mention produced a note (got '$got')"
fetch "$J2" "$BASE/board/read.cgi?bid=$anbid2&aid=$anaid"
[ "$CODE" = "200" ] || fail "anonboard read: HTTP $CODE"
has "anon ping" || fail "anonboard article body not rendered (linkify negatives would be vacuous)"
has "mention-smoke-$$" || fail "anonboard read shows a stale run's article, not this one (reseed?)"
has "profile.cgi?id=tester05" && fail "anonboard rendered a profile link for a mention"
has "to_default=tester05" && fail "anonboard rendered a note-compose link for a mention"
ok "anonboard mentions neither notify nor linkify"

# ======================================================== tier 5: attachments
# Upload -> detach round-trip (row, file, rendered link), plus the
# ghost-row case: a row whose file is already missing must still detach
# (the old del_attach silently kept it -- links rendered forever).
# File paths mirror docker/conf/*.conf AttachDir (/home/bawi/bawi-data/attach)
# and Board.pm attach_file_path (bid%100/bid/atid%100/atid).
login tester02; J2=$JAR
printf 'smoke attach payload %s\n' "$$" > "$TMP/att.txt"

fetch "$J2" "$BASE/board/write.cgi" -F "bid=2" -F "title=attach smoke" \
      -F "body=attach smoke host $$" -F "attach_no=1" -F "attach1=@$TMP/att.txt"
[ "$CODE" = "302" ] || fail "attach: write with upload: HTTP $CODE"
ataid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
atid=$(db "SELECT MAX(attach_id) FROM bw_xboard_attach WHERE article_id=$ataid") || exit 1
[ -n "$atid" ] && [ "$atid" != "NULL" ] || fail "attach row not created"
am=$((atid % 100))
af=$($DC exec -T web sh -c "test -e /home/bawi/bawi-data/attach/2/2/$am/$atid && echo yes || echo no") || exit 1
[ "$af" = "yes" ] || fail "attach file not written under AttachDir (probe: '$af')"
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$ataid"
has "attach.cgi?atid=$atid" || fail "attachment link not rendered on the article"
fetch "$J2" "$BASE/board/detach.cgi?atid=$atid&bid=2"
got=$(db "SELECT COUNT(*) FROM bw_xboard_attach WHERE attach_id=$atid") || exit 1
[ "$got" = "0" ] || fail "detach left the attach row (got '$got')"
af=$($DC exec -T web sh -c "test -e /home/bawi/bawi-data/attach/2/2/$am/$atid && echo yes || echo no") || exit 1
[ "$af" = "no" ] || fail "detach left the file on disk (probe: '$af')"
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$ataid"
has "attach smoke host" || fail "article body not rendered (negative would be vacuous)"
has "attach.cgi?atid=$atid" && fail "detached attachment still linked on the article"
ok "attachment upload and detach round-trip (row, file, link all clear)"

fetch "$J2" "$BASE/board/write.cgi" -F "bid=2" -F "title=ghost attach smoke" \
      -F "body=ghost attach host $$" -F "attach_no=1" -F "attach1=@$TMP/att.txt"
[ "$CODE" = "302" ] || fail "ghost attach: write with upload: HTTP $CODE"
gaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
gatid=$(db "SELECT MAX(attach_id) FROM bw_xboard_attach WHERE article_id=$gaid") || exit 1
[ -n "$gatid" ] && [ "$gatid" != "NULL" ] || fail "ghost: attach row not created"
gm=$((gatid % 100))
$DC exec -T web sh -c "rm -f /home/bawi/bawi-data/attach/2/2/$gm/$gatid" || fail "ghost: could not remove file out-of-band"
gf=$($DC exec -T web sh -c "test -e /home/bawi/bawi-data/attach/2/2/$gm/$gatid && echo yes || echo no") || exit 1
[ "$gf" = "no" ] || fail "ghost: file still present after rm (probe: '$gf')"
fetch "$J2" "$BASE/board/detach.cgi?atid=$gatid&bid=2"
got=$(db "SELECT COUNT(*) FROM bw_xboard_attach WHERE attach_id=$gatid") || exit 1
[ "$got" = "0" ] || fail "ghost row survived detach (old silent no-op is back; got '$got')"
ok "detach clears a ghost row whose file is already missing"

# ghost IMAGE: the board image counter tracks ROWS (del_attach
# decrements per actually-deleted row, keyed on the fetched row's
# is_img), so a ghost-image detach must decrement it -- keyed on unlink
# success it drifted upward forever
img0=$(db "SELECT images FROM bw_xboard_board WHERE board_id=2") || exit 1
$DC exec -T web perl -MImage::Magick -e 'my $i=Image::Magick->new(size=>"4x4"); $i->ReadImage("xc:red"); binmode STDOUT; $i->Write("png:-")' > "$TMP/att.png" || fail "ghost image: could not generate test PNG"
[ -s "$TMP/att.png" ] || fail "ghost image: generated PNG is empty"
fetch "$J2" "$BASE/board/write.cgi" -F "bid=2" -F "title=ghost image smoke" \
      -F "body=ghost image host $$" -F "attach_no=1" -F "attach1=@$TMP/att.png;type=image/png"
[ "$CODE" = "302" ] || fail "ghost image: write: HTTP $CODE"
giaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
giatid=$(db "SELECT MAX(attach_id) FROM bw_xboard_attach WHERE article_id=$giaid") || exit 1
[ -n "$giatid" ] && [ "$giatid" != "NULL" ] || fail "ghost image: attach row not created"
got=$(db "SELECT is_img FROM bw_xboard_attach WHERE attach_id=$giatid") || exit 1
[ "$got" = "y" ] || fail "ghost image: PNG not sniffed as image (is_img='$got') -- counter check would be vacuous"
gim=$((giatid % 100))
$DC exec -T web sh -c "rm -f /home/bawi/bawi-data/attach/2/2/$gim/$giatid" || fail "ghost image: rm failed"
fetch "$J2" "$BASE/board/detach.cgi?atid=$giatid&bid=2"
got=$(db "SELECT COUNT(*) FROM bw_xboard_attach WHERE attach_id=$giatid") || exit 1
[ "$got" = "0" ] || fail "ghost image row survived detach (got '$got')"
img1=$(db "SELECT images FROM bw_xboard_board WHERE board_id=2") || exit 1
[ "$img1" = "$img0" ] || fail "board image counter drifted on ghost-image detach ($img0 -> $img1)"
ok "ghost-image detach keeps the board image counter balanced"

# ============================================================= tier 6: polls
# Write-in polls: a poll with "voters may add an option" (uopt) needs NO
# preset-option minimum (fixed polls keep the >=2 gate). Pins the gate
# relaxation, the write-in vote path (option created once + every answer
# recorded), and the 0-seed poll's clean render (no phantom option row).
login tester02; J2=$JAR
fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "title=writein poll smoke" \
      --data-urlencode "body=writein poll host $$" \
      --data-urlencode "poll=1" \
      --data-urlencode "poll1=writein poll $$" \
      --data-urlencode "poll1_1=seed option" \
      --data-urlencode "poll1_uopt=1" \
      --data-urlencode "duration=7"
[ "$CODE" = "302" ] || fail "writein poll: write: HTTP $CODE"
plaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
plid=$(db "SELECT MAX(poll_id) FROM bw_xboard_poll WHERE article_id=$plaid") || exit 1
[ -n "$plid" ] && [ "$plid" != "NULL" ] || fail "1-option write-in poll was dropped on save (gate regression)"
got=$(db "SELECT allow_user_opt FROM bw_xboard_poll WHERE poll_id=$plid") || exit 1
[ "$got" = "1" ] || fail "allow_user_opt not stored (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_opt WHERE poll_id=$plid") || exit 1
[ "$got" = "1" ] || fail "expected exactly the seed option (got '$got')"
ok "write-in poll saves with a single seed option (uopt lifts the >=2 gate)"

login tester05; J5=$JAR
fetch "$J5" "$BASE/board/poll.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$plaid" \
      --data-urlencode "pid=$plid" \
      --data-urlencode "opt_text=voter supplied $$"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_opt WHERE poll_id=$plid") || exit 1
[ "$got" = "2" ] || fail "write-in vote did not create the voter option (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_ans WHERE poll_id=$plid") || exit 1
[ "$got" = "1" ] || fail "write-in vote not recorded in poll_ans (got '$got')"
# a second voter typing the SAME text must land on the existing option
fetch "$J2" "$BASE/board/poll.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$plaid" \
      --data-urlencode "pid=$plid" \
      --data-urlencode "opt_text=voter supplied $$"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_opt WHERE poll_id=$plid") || exit 1
[ "$got" = "2" ] || fail "duplicate write-in created a second option (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_ans WHERE poll_id=$plid") || exit 1
[ "$got" = "2" ] || fail "duplicate write-in vote not recorded (got '$got')"
ok "write-in votes create the option once and record every answer"

# 0-seed write-in poll: saves clean (no phantom autovivified option row)
# and takes its first write-in vote
fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "title=zeroseed poll smoke" \
      --data-urlencode "body=zeroseed poll host $$" \
      --data-urlencode "poll=1" \
      --data-urlencode "poll1=zeroseed poll $$" \
      --data-urlencode "poll1_uopt=1" \
      --data-urlencode "poll2=zero option poll $$" \
      --data-urlencode "poll2_1=0" \
      --data-urlencode "poll2_2=1" \
      --data-urlencode "poll2_3=2" \
      --data-urlencode "duration=7"
[ "$CODE" = "302" ] || fail "zeroseed poll: write: HTTP $CODE"
zaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
# poll1 (the 0-seed write-in) gets the LOWER poll_id; poll2 (fixed) the higher
zpid=$(db "SELECT MIN(poll_id) FROM bw_xboard_poll WHERE article_id=$zaid") || exit 1
[ -n "$zpid" ] && [ "$zpid" != "NULL" ] || fail "0-seed write-in poll was dropped on save"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_opt WHERE poll_id=$zpid") || exit 1
[ "$got" = "0" ] || fail "0-seed poll has options (got '$got')"
# the sibling FIXED poll on the same article seeds a literal "0" option,
# which truthiness filtering used to drop silently
fpid=$(db "SELECT MAX(poll_id) FROM bw_xboard_poll WHERE article_id=$zaid") || exit 1
[ "$fpid" != "$zpid" ] || fail "fixed sibling poll was not created"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_opt WHERE poll_id=$fpid") || exit 1
[ "$got" = "3" ] || fail "fixed poll expected 3 seed options incl '0' (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_opt WHERE poll_id=$fpid AND opt='0'") || exit 1
[ "$got" = "1" ] || fail "the literal '0' seed option was dropped (got '$got')"
ok "a fixed poll keeps a literal 0 seed option"
fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$zaid"
[ "$CODE" = "200" ] || fail "zeroseed read: HTTP $CODE"
has "zeroseed poll $$" || fail "0-seed poll question not rendered (phantom check would be vacuous)"
has 'name="oid" value=""' && fail "phantom empty radio rendered for the 0-seed poll (autovivification is back)"
fetch "$J5" "$BASE/board/poll.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "aid=$zaid" \
      --data-urlencode "pid=$zpid" \
      --data-urlencode "opt_text=zeroseed choice $$"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_opt WHERE poll_id=$zpid") || exit 1
[ "$got" = "1" ] || fail "0-seed write-in vote did not create the option (got '$got')"
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_ans WHERE poll_id=$zpid") || exit 1
[ "$got" = "1" ] || fail "0-seed write-in vote not recorded (got '$got')"
ok "0-seed write-in poll saves clean and takes its first write-in vote"

# ======================================================= tier 7: cross-tabs
# Fresh 2-poll article so no earlier tier's votes can pollute the cells.
# Seeded ki is deterministic (uid N -> ki 10+N%25; root/uid 1 is ki 1):
# tester02..05 carry ki 12..15, tester06 carries 16 -- the band-label
# assertions depend on it. Every seeded cohort has at most 2 members, so
# dense (>=3 voter) cohorts are fabricated by direct insert where needed.
fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "title=xtab smoke" \
      --data-urlencode "body=xtab host $$" \
      --data-urlencode "poll=1" \
      --data-urlencode "poll1=xtab q1 $$" \
      --data-urlencode "poll1_1=xtA" \
      --data-urlencode "poll1_2=xtB" \
      --data-urlencode "poll2=xtab q2 $$" \
      --data-urlencode "poll2_1=xtC" \
      --data-urlencode "poll2_2=xtD" \
      --data-urlencode "duration=7"
[ "$CODE" = "302" ] || fail "xtab: write: HTTP $CODE"
# id recovery: MIN = first seeded (poll1 / options xtA,xtC), MAX = the
# second (poll2 / xtB,xtD) -- same insertion-order rule tier 6 documents
xaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
xp1=$(db "SELECT MIN(poll_id) FROM bw_xboard_poll WHERE article_id=$xaid") || exit 1
xp2=$(db "SELECT MAX(poll_id) FROM bw_xboard_poll WHERE article_id=$xaid") || exit 1
xoA=$(db "SELECT MIN(opt_id) FROM bw_xboard_poll_opt WHERE poll_id=$xp1") || exit 1
xoB=$(db "SELECT MAX(opt_id) FROM bw_xboard_poll_opt WHERE poll_id=$xp1") || exit 1
xoC=$(db "SELECT MIN(opt_id) FROM bw_xboard_poll_opt WHERE poll_id=$xp2") || exit 1
xoD=$(db "SELECT MAX(opt_id) FROM bw_xboard_poll_opt WHERE poll_id=$xp2") || exit 1

fetch "$J2" "$BASE/board/read.cgi?bid=2&aid=$xaid"
[ "$CODE" = "200" ] || fail "xtab: read: HTTP $CODE"
has "poll.cgi?bid=2;aid=$xaid" || fail "read page carries no cross-tab link"
ok "article page links to the cross-tab entry page"

login tester07; J7=$JAR
fetch "$J7" "$BASE/board/poll.cgi?bid=2&aid=$xaid&mode=xtab&p1=$xp1&p2=$xp2"
[ "$CODE" = "200" ] || fail "xtab gated: HTTP $CODE"
has "투표 후 이용해 주세요" || fail "unvoted viewer got silence, not the gated message"
ok "cross-tab before voting explains the gate instead of rendering nothing"

for u in tester02 tester03 tester04 tester05; do
    login "$u"
    fetch "$JAR" "$BASE/board/poll.cgi" \
          --data-urlencode "bid=2" --data-urlencode "aid=$xaid" \
          --data-urlencode "pid=$xp1" --data-urlencode "oid=$xoA"
    fetch "$JAR" "$BASE/board/poll.cgi" \
          --data-urlencode "bid=2" --data-urlencode "aid=$xaid" \
          --data-urlencode "pid=$xp2" --data-urlencode "oid=$xoC"
done
got=$(db "SELECT COUNT(*) FROM bw_xboard_poll_ans WHERE poll_id IN ($xp1,$xp2)") || exit 1
[ "$got" = "8" ] || fail "xtab: expected 8 aligned answers (got '$got')"
login tester02; J2=$JAR
fetch "$J2" "$BASE/board/poll.cgi?bid=2&aid=$xaid&mode=xtab&p1=$xp1&p2=$xp2"
has "두 질문 모두 응답: 4명" || fail "poll x poll matrix did not render with n=4"
ok "poll x poll cross-tab renders once every populated cell clears 3"

fetch "$J2" "$BASE/board/poll.cgi?bid=2&aid=$xaid&mode=xtab&p1=$xp1&p2=ki"
has "12~15기" || fail "ki axis did not merge the sparse cohorts into 12~15기"
has "기수 등록 응답자: 4명" || fail "ki footer missing or wrong n"
ok "poll x ki adaptively merges 1-voter cohorts into one band"

# a dense cohort must keep 1-ki resolution while sparse neighbors merge:
# fabricate a 3-voter ki-40 cohort by direct insert. The synthetic uids
# answer poll 1 only, so the poll x poll cross-tab (a self-join over
# BOTH polls) never sees them.
for u in 9001 9002 9003; do
    db "INSERT INTO bw_user_ki (uid, ki) VALUES ($u, 40)" || exit 1
    db "INSERT INTO bw_xboard_poll_ans (poll_id, uid, opt_id) VALUES ($xp1, $u, $xoA)" || exit 1
done
fetch "$J2" "$BASE/board/poll.cgi?bid=2&aid=$xaid&mode=xtab&p1=$xp1&p2=ki"
has "12~15기" || fail "sparse cohorts no longer merge once a dense band exists"
has "40기" || fail "a 3-voter cohort did not stand as its own band"
ok "dense cohorts stand alone while sparse neighbors merge (multi-band render)"

login tester06; J6=$JAR
fetch "$J6" "$BASE/board/poll.cgi" \
      --data-urlencode "bid=2" --data-urlencode "aid=$xaid" \
      --data-urlencode "pid=$xp1" --data-urlencode "oid=$xoB"
fetch "$J6" "$BASE/board/poll.cgi" \
      --data-urlencode "bid=2" --data-urlencode "aid=$xaid" \
      --data-urlencode "pid=$xp2" --data-urlencode "oid=$xoD"
login tester02; J2=$JAR
fetch "$J2" "$BASE/board/poll.cgi?bid=2&aid=$xaid&mode=xtab&p1=$xp1&p2=$xp2"
has "표시하지 않습니다" || fail "a 1-voter cell did not suppress the poll x poll table"
ok "poll x poll whole-table <3 suppression still fires"

# the same stray vote poisons the ki axis: 16기's lone B answer drags
# every band into one that still holds a 1-voter cell -- the terminal
# check must suppress it, never publish (the single-band state is NOT
# the public tally: it is cohort-labeled and excludes ki-less voters)
fetch "$J2" "$BASE/board/poll.cgi?bid=2&aid=$xaid&mode=xtab&p1=$xp1&p2=ki"
has "표시하지 않습니다" || fail "a sparse single-band ki table was published (terminal suppression missing)"
ok "a ki table that cannot merge itself safe is suppressed"

# ki-less remainder: when public answers exceed the ki table's n by 1-2,
# subtracting column sums from the public tally pins those voters. Three
# registered voters render fine; one ki-less answer must flip the table
# to suppressed.
fetch "$J2" "$BASE/board/write.cgi" \
      --data-urlencode "bid=2" \
      --data-urlencode "title=kiless smoke" \
      --data-urlencode "body=kiless host $$" \
      --data-urlencode "poll=1" \
      --data-urlencode "poll1=kiless q $$" \
      --data-urlencode "poll1_1=klA" \
      --data-urlencode "poll1_2=klB" \
      --data-urlencode "duration=7"
[ "$CODE" = "302" ] || fail "kiless: write: HTTP $CODE"
kaid=$(db "SELECT MAX(article_id) FROM bw_xboard_header WHERE board_id=2") || exit 1
kpid=$(db "SELECT MAX(poll_id) FROM bw_xboard_poll WHERE article_id=$kaid") || exit 1
koA=$(db "SELECT MIN(opt_id) FROM bw_xboard_poll_opt WHERE poll_id=$kpid") || exit 1
for u in tester02 tester03 tester04; do
    login "$u"
    fetch "$JAR" "$BASE/board/poll.cgi" \
          --data-urlencode "bid=2" --data-urlencode "aid=$kaid" \
          --data-urlencode "pid=$kpid" --data-urlencode "oid=$koA"
done
login tester02; J2=$JAR
fetch "$J2" "$BASE/board/poll.cgi?bid=2&aid=$kaid&mode=xtab&p1=$kpid&p2=ki"
has "기수 등록 응답자: 3명" || fail "kiless precondition: 3-voter table did not render"
db "INSERT INTO bw_xboard_poll_ans (poll_id, uid, opt_id) VALUES ($kpid, 9010, $koA)" || exit 1
fetch "$J2" "$BASE/board/poll.cgi?bid=2&aid=$kaid&mode=xtab&p1=$kpid&p2=ki"
has "표시하지 않습니다" || fail "a 1-voter ki-less remainder did not suppress the ki table"
ok "a 1-2 voter ki-less remainder suppresses the ki table (subtraction guard)"

[ "$N" -eq "$EXPECTED" ] || fail "ran $N of $EXPECTED checks -- a check was skipped or removed without updating EXPECTED"
echo "all $N checks passed"
