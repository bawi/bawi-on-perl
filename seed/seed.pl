#!/usr/bin/perl
# =============================================================================
# seed.pl — deterministic SYNTHETIC data seeder for the bawi test database
# =============================================================================
# Fills the structure-only test schema with clean, obviously-fake data:
# no real users, no PII, no production content. Every name/id/email/phone is
# a labeled synthetic value (testuserNN, @example.invalid, 010-0000-xxxx).
#
# Deterministic: uses a private LCG (seeded below), so two runs produce
# byte-identical data on any platform. Re-running truncates and reseeds the
# tables it owns (idempotent).
#
# Run inside the web container (which has DBI + DBD::mysql):
#   docker compose exec web perl /home/bawi/bawi-spring/seed/seed.pl
#
# Connection comes from BAWI_DB_{HOST,NAME,USER,PASS} (set in
# docker-compose.yml), falling back to the compose defaults.
#
# What gets seeded / what stays empty: see the table at the bottom of this
# header.
#
#   SEEDED: bw_xauth_passwd (50 users, all password "test1234"),
#     bw_user_ki, bw_user_basic, bw_user_sig, bw_user_access,
#     bw_group (3), bw_group_user, bw_xboard_board (6),
#     bw_xboard_header/body (320 articles; 5 are category=1 markdown, to
#     exercise Bawi::Markdown + the bw_xboard_body_html render cache),
#     bw_xboard_comment (320),
#     bw_xboard_notice, bw_xboard_recom, bw_xboard_bookmark, bw_note (40),
#     bw_xboard_poll/_opt/_ans (2 article polls), bw_xpoll/_question/_choice
#     (1 survey), countries, schools, majors, circles, registers,
#     bw_data_major, bw_user_major, bw_user_degree, bw_user_circle,
#     organizations, org_alias, bw_user_career (career v3.2), loads,
#     bw_xboard_stat_board/_article/_user (aggregated from the seed).
#   EMPTY (documented): bw_xboard_attach (no files on disk), bw_xboard_scrap,
#     bw_xboard_tag, bw_xboard_tagmap, bw_xboard_commentref, bw_xauth_session
#     (created at login), bw_xboard_body_html (read-through render cache,
#     self-populating on first view), bw_xauth_new_passwd, bw_user_photo,
#     bw_user_gbook, bw_user_support, bw_symp, bw_user_access_history,
#     bawi_access_stat, bw_note_notify_boxcar, bw_postman_log,
#     bw_poll* (legacy), bw_xpoll_check, notes (legacy).
#     Reseed truncates EVERY base table except schema_migrations (derived
#     from information_schema, so it can't drift), then reseeds — no UI
#     experiment survives a "wipe + reseed".
#     Deterministic caveat: columns with DEFAULT CURRENT_TIMESTAMP that the
#     seeder leaves unset (bw_xboard_body.modified, bw_user_basic.modified,
#     bw_user_access.last_access, organizations.created_date) take the run's
#     wall clock; every value the seeder writes explicitly is deterministic.
# =============================================================================
use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

# ---------------------------------------------------------------- connection
my $host = $ENV{BAWI_DB_HOST} || 'db';
my $name = $ENV{BAWI_DB_NAME} || 'bawi';
my $user = $ENV{BAWI_DB_USER} || 'bawi_test';
my $pass = $ENV{BAWI_DB_PASS} || 'bawi-local-test-pw';

# Bounded connect-retry: on a first boot the DB container may still be
# loading the schema; it only answers over the network after init (schema +
# migrations) is complete, so "connects" == "ready to seed".
my $dbh;
for my $try (1 .. 90) {
    $dbh = eval { DBI->connect("dbi:mysql:database=$name;host=$host", $user, $pass,
                               { RaiseError => 1, PrintError => 0 }) };
    last if $dbh;
    print "waiting for the DB at $host ($try s) ...\n" if $try == 1 || $try % 15 == 0;
    sleep 1;
}
die "cannot connect to $name\@$host after 90s: $@" unless $dbh;
$dbh->do("SET NAMES utf8mb4");

# ------------------------------------------------------------- determinism
# Private LCG so output is identical across perl versions/platforms.
my $lcg_state = 20260706;
sub prng { $lcg_state = ($lcg_state * 1103515245 + 12345) % 2147483648; return $lcg_state }
sub pick { my $n = shift; return prng() % $n }

# Deterministic clock: everything is derived from this fixed base (UTC).
use constant BASE_EPOCH => 1735689600;      # 2025-01-01 00:00:00 UTC
sub dt { my $epoch = shift; return strftime('%Y-%m-%d %H:%M:%S', gmtime($epoch)) }
sub d  { my $epoch = shift; return strftime('%Y-%m-%d', gmtime($epoch)) }

# ------------------------------------------------------- password (DES crypt)
# The app authenticates with  passwd = ENCRYPT(?, passwd)  server-side, so
# server-side DES crypt MUST work. Fail loudly here rather than at login time.
my $TEST_PASSWORD = 'test1234';   # (DES crypt only uses the first 8 chars)
my ($pw_hash) = $dbh->selectrow_array(q{SELECT ENCRYPT(?, 'bw')}, undef, $TEST_PASSWORD);
die "FATAL: MariaDB ENCRYPT() returned NULL — DES crypt unavailable in the db container; logins would be impossible\n"
    unless defined $pw_hash && length($pw_hash) == 13;
print "password hash for '$TEST_PASSWORD': $pw_hash\n";

# ---------------------------------------------------------------- constants
# uid 1 = "root": generic admin account name that matches the hardcoded admin
# list in Bawi::Auth::is_admin, so admin paths are testable. Not a real person.
my $N_USERS = 50;   # <= 99: 'testuserNN' must fit the app's char(10)/varchar(10) id columns
# Guards live BEFORE the wipe so a bad edit dies without emptying the DB.
die "N_USERS must be <= 99 ('testuser100' would overflow 10-char id columns)\n" if $N_USERS > 99;
# Floor: registers (uids 46..50), degrees (2..46), careers (2..25) and other
# blocks hardcode uid ranges; a smaller pool would seed orphan references.
die "N_USERS must be >= 50 (later blocks hardcode uid ranges up to 50)\n" if $N_USERS < 50;

# ------------------------------------------------------------------- wipe
# Truncate every base table except the migration ledger, so "wipe + reseed"
# is true by construction — a hand-kept list drifts as migrations add tables
# (and already had: UI-writable tables were missing). No migration seeds
# reference rows, so truncate-all is safe (per the migration runner's
# CONTRACT header: rows a migration ships for prod must be mirrored here).
my $tables = $dbh->selectcol_arrayref(q{
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'
      AND table_name <> 'schema_migrations'});
print "truncating ", scalar(@$tables), " tables ...\n";
$dbh->do("TRUNCATE TABLE `$_`") for @$tables;

# ------------------------------------------------------------------ users
print "seeding $N_USERS users (ids: root, testuser02..testuser$N_USERS; password: $TEST_PASSWORD)\n";
my %uname;   # uid -> display name
my %uid2id;  # uid -> login id
{
    my $sth = $dbh->prepare(q{
        INSERT INTO bw_xauth_passwd (uid, id, name, passwd, email, modified, accessed, access)
        VALUES (?,?,?,?,?,?,?,?)});
    my $ki  = $dbh->prepare(q{INSERT INTO bw_user_ki (uid, ki) VALUES (?,?)});
    my $bas = $dbh->prepare(q{
        INSERT INTO bw_user_basic (uid, ename, mobile_tel, birth, affiliation, title, greeting)
        VALUES (?,?,?,?,?,?,?)});
    my $acc = $dbh->prepare(q{INSERT INTO bw_user_access (uid, id, count) VALUES (?,?,?)});

    for my $uid (1 .. $N_USERS) {
        my ($id, $nm);
        if ($uid == 1) { ($id, $nm) = ('root', '관리자테스트') }
        else           { $id = sprintf('testuser%02d', $uid); $nm = sprintf('테스트유저%02d', $uid) }
        $uid2id{$uid} = $id;
        $uname{$uid}  = $nm;
        my $modified = dt(BASE_EPOCH + 86400 * (300 + $uid));       # recent-ish
        my $accessed = dt(BASE_EPOCH + 86400 * 500 + 3600 * $uid);
        $sth->execute($uid, $id, $nm, $pw_hash, "$id\@example.invalid",
                      $modified, $accessed, 100 + $uid * 3);
        $ki->execute($uid, $uid == 1 ? 1 : 10 + ($uid % 25));
        $bas->execute($uid, sprintf('Test User %02d', $uid),
                      sprintf('010-0000-%04d', $uid),
                      d(BASE_EPOCH - 86400 * 365 * (25 + $uid % 20)),
                      sprintf('가상연구소 %02d', 1 + $uid % 7),
                      '테스트직함',
                      "합성 테스트 계정입니다 (synthetic test account #$uid).",
        );
        $acc->execute($uid, $id, 10 + $uid);
    }
    my $sig = $dbh->prepare(q{INSERT INTO bw_user_sig (uid, sig) VALUES (?,?)});
    $sig->execute($_, "-- 테스트 서명 $_ (synthetic signature)") for 2 .. 10;
}

# ----------------------------------------------------------------- groups
print "seeding 3 groups + memberships\n";
{
    my $g = $dbh->prepare(q{
        INSERT INTO bw_group (gid, pgid, title, keyword, uid, type, seq, created,
                              g_sub, m_sub, a_sub, g_board, m_board, a_board)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)});
    $g->execute(1, 0, '바위 테스트',   'bawitest',   1, 'open',   1, dt(BASE_EPOCH), 1,1,0,1,1,0);
    $g->execute(2, 1, '동호회 테스트', 'clubtest',   1, 'open',   2, dt(BASE_EPOCH), 1,1,0,1,1,0);
    $g->execute(3, 1, '비공개 테스트', 'closedtest', 1, 'closed', 3, dt(BASE_EPOCH), 0,1,0,0,1,0);

    my $gu = $dbh->prepare(q{
        INSERT INTO bw_group_user (gid, uid, status, created) VALUES (?,?,'active',?)});
    $gu->execute(1, $_, dt(BASE_EPOCH + 3600 * $_)) for 1 .. $N_USERS;
    $gu->execute(2, $_, dt(BASE_EPOCH + 7200 * $_)) for 2 .. 21;
    $gu->execute(3, $_, dt(BASE_EPOCH + 9600 * $_)) for 2 .. 6;
}

# ----------------------------------------------------------------- boards
#  id keyword  gid title                 anon-read  articles
my @BOARDS = (
    [1, 'notice', 1, '공지사항 테스트',   1,  15],
    [2, 'free',   1, '자유게시판 테스트', 0, 150],
    [3, 'qna',    1, '질문답변 테스트',   0,  60],
    [4, 'career', 1, '진로 테스트',       0,  45],
    [5, 'photo',  1, '사진 테스트',       0,  25],
    [6, 'club',   2, '동호회 테스트판',   0,  25],
);
print "seeding ", scalar(@BOARDS), " boards\n";
{
    my $b = $dbh->prepare(q{
        INSERT INTO bw_xboard_board
            (board_id, keyword, gid, title, uid, id, name, skin, seq, created,
             is_imgboard, a_read, a_write, a_comment)
        VALUES (?,?,?,?,?,?,?,'default',?,?,?,?,0,0)});
    for my $bd (@BOARDS) {
        my ($bid, $kw, $gid, $title, $anon, $n) = @$bd;
        $b->execute($bid, $kw, $gid, $title, 1, 'root', $uname{1},
                    $bid, dt(BASE_EPOCH + 86400 * $bid), ($kw eq 'photo' ? 1 : 0), $anon);
    }
}

# --------------------------------------------------------------- articles
print "seeding articles (headers + bodies) ...\n";
my $article_id = 0;
my %first_article_id;        # board_id -> article_id of article_no 1
my %poll_articles;           # article_id -> board_id (articles that get a poll)
my @article_rows;            # [article_id, board_id, article_no, uid, created_epoch]
{
    my $h = $dbh->prepare(q{
        INSERT INTO bw_xboard_header
            (article_id, article_no, parent_no, thread_no, board_id, category,
             title, uid, id, name, count, recom, scrap, comments,
             has_attach, has_poll, created)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,0,0,0,0,?,?)});
    my $bo = $dbh->prepare(q{
        INSERT INTO bw_xboard_body (article_id, board_id, body) VALUES (?,?,?)});

    for my $bd (@BOARDS) {
        my ($bid, $kw, $gid, $btitle, $anon, $n) = @$bd;
        my @thread;                       # per-board stack of recent top-levels
        for my $no (1 .. $n) {
            $article_id++;
            my $author  = 2 + (($article_id * 7) % ($N_USERS - 1));   # uid 2..50
            my $created = BASE_EPOCH + 86400 * 30 + $article_id * 3600 * 7;
            my ($parent_no, $thread_no) = (0, $no);
            if ($no > 1 && ($no % 4 == 0) && @thread) {               # every 4th: a reply
                my $p = $thread[-1];
                ($parent_no, $thread_no) = ($p->[0], $p->[1]);
            } else {
                push @thread, [$no, $no];
                shift @thread while @thread > 3;
            }
            my $title = $parent_no
                ? sprintf('Re: [테스트] %s 글 %03d', $btitle, $parent_no)
                : sprintf('[테스트] %s 글 %03d — synthetic', $btitle, $no);
            # bw_xboard_header.title is char(64); this script has no `use utf8`,
            # so length() counts BYTES — a blind substr could cut mid-Hangul.
            # Titles are ours and deterministic: fail loudly instead.
            die "seed bug: title exceeds 64 bytes (shorten the board title in \@BOARDS): $title\n"
                if length($title) > 64;
            my $has_poll = 0;
            if (($kw eq 'free' && $no == 10) || ($kw eq 'career' && $no == 5)) {
                $has_poll = 1;
                $poll_articles{$article_id} = $bid;
            }
            # 5 markdown articles: category=1 routes reads through
            # Bawi::Markdown::render + the bw_xboard_body_html cache
            # (lib/Bawi/Board.pm format_article), the newest read path.
            my $category = ($kw eq 'free' && $no >= 20 && $no <= 24) ? 1 : 0;
            $h->execute($article_id, $no, $parent_no, $thread_no, $bid, $category,
                        $title, $author, $uid2id{$author}, $uname{$author},
                        pick(200), $has_poll, dt($created));
            my $body = $category
                ? join("\n",
                    "## 마크다운 테스트 글 $no (markdown test)",
                    "",
                    "이 글은 **category=1** 로 저장되어 읽기 시점에 Bawi::Markdown 으로",
                    "렌더링되고, 결과가 `bw_xboard_body_html` 캐시에 기록됩니다.",
                    "",
                    "- 목록 항목 하나",
                    "- 목록 항목 둘 — [링크](https://example.invalid/md-$no)",
                    "",
                    "```perl",
                    "print \"fenced code block #$no\\n\";",
                    "```",
                  )
                : join("\n",
                    "이 글은 테스트 환경용 합성 데이터입니다. (SYNTHETIC TEST DATA)",
                    "게시판: $btitle / 글 번호: $no / article_id: $article_id",
                    "작성자: $uname{$author} ($uid2id{$author}) — 실존 인물이 아닙니다.",
                    "",
                    "본문 채움 문단입니다. 페이지네이션과 목록/읽기 화면을 시험하기 위한",
                    "내용이며 실제 서비스 데이터와 무관합니다. " . ('테스트 문장입니다. ' x (1 + $no % 5)),
                    "",
                    "Filler paragraph #$no for list/read/pagination testing.",
                  );
            $bo->execute($article_id, $bid, $body);
            $first_article_id{$bid} = $article_id if $no == 1;
            push @article_rows, [$article_id, $bid, $no, $author, $created];
        }
    }
    print "  $article_id articles\n";
}

# --------------------------------------------------------------- comments
print "seeding comments ...\n";
{
    my $c = $dbh->prepare(q{
        INSERT INTO bw_xboard_comment
            (comment_id, comment_no, board_id, article_id, body, uid, id, name, created)
        VALUES (?,?,?,?,?,?,?,?,?)});
    my $comment_id = 0;
    my %board_comment_no;                 # per-board running comment_no
    for my $ar (@article_rows) {
        my ($aid, $bid, $no, $author, $created) = @$ar;
        next if $aid % 2;                 # every 2nd article gets comments
        my $n = 1 + ($aid % 4);           # 1..4 comments
        for my $k (1 .. $n) {
            $comment_id++;
            my $cno = ++$board_comment_no{$bid};
            my $cuid = 2 + (($aid * 3 + $k * 11) % ($N_USERS - 1));
            $c->execute($comment_id, $cno, $bid, $aid,
                        "테스트 댓글 $k (synthetic comment on article $aid)",
                        $cuid, $uid2id{$cuid}, $uname{$cuid},
                        dt($created + 600 * $k));
        }
    }
    print "  $comment_id comments\n";
}

# ------------------------------------------------------- recommendations
print "seeding recommendations ...\n";
{
    my $r = $dbh->prepare(q{
        INSERT INTO bw_xboard_recom (uid, article_id, rectime) VALUES (?,?,?)});
    my $n = 0;
    for my $ar (@article_rows) {
        my ($aid, $bid, $no, $author, $created) = @$ar;
        my $k = $aid % 6;                 # 0..5 recommendations
        for my $i (1 .. $k) {
            $r->execute(1 + $i, $aid, dt($created + 3600 + 60 * $i));  # uids 2..6
            $n++;
        }
    }
    print "  $n recommendations\n";
}

# ------------------------------------------------------ notices, bookmarks
print "seeding notices + bookmarks\n";
{
    my $nt = $dbh->prepare(q{INSERT INTO bw_xboard_notice (board_id, article_id) VALUES (?,?)});
    $nt->execute($_->[0], $first_article_id{$_->[0]}) for @BOARDS;

    my $bm = $dbh->prepare(q{
        INSERT INTO bw_xboard_bookmark (uid, board_id, article_no, comment_no, seq)
        VALUES (?,?,?,?,?)});
    for my $uid (1 .. 10) {
        my $seq = 0;
        for my $bid (1, 2, 3, 4, 6) {
            # last-read position a bit behind the tip -> "new article" markers
            my ($board) = grep { $_->[0] == $bid } @BOARDS;
            my $max_no  = $board->[5];             # articles column of @BOARDS
            my $behind  = 3 + ($uid % 4);
            my $article_no = $max_no > $behind ? $max_no - $behind : 0;
            $bm->execute($uid, $bid, $article_no, 0, ++$seq);
        }
    }
}

# ------------------------------------------------------------------ notes
print "seeding 40 notes\n";
{
    my $n = $dbh->prepare(q{
        INSERT INTO bw_note (msg_id, to_id, to_name, from_id, from_name, msg, sent_time, read_time)
        VALUES (?,?,?,?,?,?,?,?)});
    for my $i (0 .. 39) {
        my $from = 1 + ($i % 10);
        my $to   = 1 + (($i + 3) % 10);
        my $sent = BASE_EPOCH + 86400 * 400 + $i * 10800;
        $n->execute($i + 1,
                    $uid2id{$to},   $uname{$to},
                    $uid2id{$from}, $uname{$from},
                    "합성 쪽지 #@{[$i+1]} 입니다. (synthetic note, not real correspondence)",
                    dt($sent),
                    ($i < 30 ? dt($sent + 3600) : undef));   # last 10 unread
    }
}

# ------------------------------------------------------------ article polls
print "seeding 2 article polls\n";
{
    my $p  = $dbh->prepare(q{
        INSERT INTO bw_xboard_poll (poll_id, board_id, article_id, poll, created, closed)
        VALUES (?,?,?,?,?,?)});
    my $po = $dbh->prepare(q{
        INSERT INTO bw_xboard_poll_opt (opt_id, poll_id, opt, count) VALUES (?,?,?,?)});
    my $pa = $dbh->prepare(q{
        INSERT INTO bw_xboard_poll_ans (poll_id, uid, opt_id) VALUES (?,?,?)});

    my ($poll_id, $opt_id) = (0, 0);
    for my $aid (sort { $a <=> $b } keys %poll_articles) {
        $poll_id++;
        my $bid = $poll_articles{$aid};
        $p->execute($poll_id, $bid, $aid, "테스트 설문 $poll_id (synthetic poll)",
                    dt(BASE_EPOCH + 86400 * 200), dt(BASE_EPOCH + 86400 * 900));
        my @opts;
        for my $o (1 .. 3) {
            $opt_id++;
            push @opts, $opt_id;
            $po->execute($opt_id, $poll_id, "보기 $o (option $o)", 0);
        }
        for my $u (2 .. 13) {                       # 12 voters
            my $choice = $opts[$u % 3];
            $pa->execute($poll_id, $u, $choice);
        }
    }
    $dbh->do(q{UPDATE bw_xboard_poll_opt o
               SET count = (SELECT COUNT(*) FROM bw_xboard_poll_ans a
                            WHERE a.opt_id = o.opt_id)});
}

# --------------------------------------------------------------- xpoll (survey)
print "seeding 1 survey (bw_xpoll)\n";
{
    $dbh->do(q{INSERT INTO bw_xpoll
        (poll_id, uid, name, id, dt_start, dt_end, opt_hide, numofq,
         poll_title, poll_txt, lk, participant, poll_comment)
        VALUES (1, 'root', ?, 'root', ?, ?, 0, 2,
                '테스트 설문조사 (synthetic)', '테스트용 설문입니다.', 0, 12, '')},
        undef, $uname{1}, d(BASE_EPOCH + 86400 * 380), d(BASE_EPOCH + 86400 * 900));
    my $q = $dbh->prepare(q{
        INSERT INTO bw_xpoll_question (question_id, question_txt, poll_id) VALUES (?,?,1)});
    $q->execute(1, '테스트 질문 1 (synthetic question 1)');
    $q->execute(2, '테스트 질문 2 (synthetic question 2)');
    my $c = $dbh->prepare(q{
        INSERT INTO bw_xpoll_choice (choice_id, question_id, choice_txt, choice_count, choice_q)
        VALUES (?,?,?,?,?)});
    my $cid = 0;
    for my $qid (1, 2) {
        for my $o (1 .. 3) {
            $cid++;
            $c->execute($cid, $qid, "선택지 $o (choice $o)", ($o == 1 ? 6 : ($o == 2 ? 4 : 2)), $qid);
        }
    }
}

# ------------------------------------------------- registration lookup data
print "seeding registration lookups (countries/schools/majors/circles/registers)\n";
{
    my $co = $dbh->prepare(q{INSERT INTO countries (id, name, code) VALUES (?,?,?)});
    $co->execute(1, '대한민국', 'KR');
    $co->execute(2, 'United States', 'US');
    $co->execute(3, 'Japan', 'JP');
    $co->execute(4, 'Canada', 'CA');

    my $sc = $dbh->prepare(q{
        INSERT INTO schools (id, full_name, brief_name, url, country_code) VALUES (?,?,?,?,?)});
    my @schools = (
        [1, '가상대학교',            '가상대',    'https://example.invalid/u1', 'KR'],
        [2, '모의과학기술원',        '모의과기원','https://example.invalid/u2', 'KR'],
        [3, 'Example University',    'ExampleU',  'https://example.invalid/u3', 'US'],
        [4, 'Sample Institute',      'SampleI',   'https://example.invalid/u4', 'US'],
        [5, 'Synthetic College',     'SynthC',    'https://example.invalid/u5', 'CA'],
        [6, 'テスト大学 (fictional)','テスト大',  'https://example.invalid/u6', 'JP'],
    );
    $sc->execute(@$_) for @schools;

    my $mj = $dbh->prepare(q{INSERT INTO majors (id, parent_id, name) VALUES (?,?,?)});
    my $dm = $dbh->prepare(q{INSERT INTO bw_data_major (major_id, parent_id, major) VALUES (?,?,?)});
    my @majors = ([1,0,'자연과학'],[2,0,'공학'],[3,1,'수학'],[4,1,'물리학'],
                  [5,1,'생물학'],[6,2,'전산학'],[7,2,'전자공학'],[8,2,'기계공학']);
    for my $m (@majors) { $mj->execute(@$m); $dm->execute(@$m) }

    my $ci = $dbh->prepare(q{INSERT INTO circles (id, name) VALUES (?,?)});
    $ci->execute(1, '가상산악회'); $ci->execute(2, '모의사진반');
    $ci->execute(3, '테스트합창단'); $ci->execute(4, '샘플바둑부');

    # registers: fake alumni roster rows for exercising reg/register.cgi.
    # pins are clearly fake (9xxxxxxx); rows 1-5 already linked to test uids.
    my $rg = $dbh->prepare(q{
        INSERT INTO registers (id, pin, ki, name, born_on, category, remarks, uid, member_status)
        VALUES (?,?,?,?,?,'졸업','synthetic',?,?)});
    for my $i (1 .. 30) {
        my $uid = $i <= 5 ? 45 + $i : undef;
        $rg->execute($i, 90000000 + $i, 10 + ($i % 25),
                     sprintf('가상졸업생%02d', $i),
                     d(BASE_EPOCH - 86400 * 365 * (30 + $i % 15)),
                     $uid, ($uid ? '정' : ''));
    }
}

# ------------------------------------------ career-adjacent user profile data
print "seeding degrees / majors / circles per user\n";
{
    my @types = ('Bachelor','Master','Doctor','Postdoc','Resident','Fellow');
    # status vocabulary lives in app code, not the schema (varchar):
    # Bawi::User::get_degree maps exactly these five to display labels.
    my @statuses = ('graduated','course_completed','admitted','other');
    my $dg = $dbh->prepare(q{
        INSERT INTO bw_user_degree
            (degree_id, uid, type, school_id, department, advisors, content,
             start_date, end_date, status)
        VALUES (?,?,?,?,?,?,?,?,?,?)});
    my $did = 0;
    for my $uid (2 .. 46) {
        $did++;
        my $type    = $types[$uid % 6];   # all 6 bw_user_degree.type values (incl. the 20161225_add_career_enum.sql additions)
        my $start   = BASE_EPOCH - 86400 * 365 * (10 - $uid % 8);
        my $current = $uid % 3 == 0;
        $dg->execute($did, $uid, $type, 1 + ($uid % 6),
                     '가상학과 (synthetic dept)', 'Prof. Placeholder',
                     'synthetic degree record for career-feature testing',
                     d($start),
                     $current ? '1001-01-01' : d($start + 86400 * 365 * 4),
                     $current ? 'attending' : $statuses[$uid % 4]);
    }
    my $um = $dbh->prepare(q{INSERT INTO bw_user_major (uid, major_id) VALUES (?,?)});
    $um->execute($_, 3 + ($_ % 6)) for 2 .. 41;     # child majors 3..8
    my $uc = $dbh->prepare(q{INSERT INTO bw_user_circle (uid, circle_id) VALUES (?,?)});
    $uc->execute($_, 1 + ($_ % 4)) for 2 .. 20;
}

# ------------------------------------------------------------ career (v3.2)
print "seeding career entries (organizations / org_alias / bw_user_career)\n";
{
    my $org = $dbh->prepare(q{
        INSERT INTO organizations (org_id, name, created_by) VALUES (?,?,1)});
    my $al  = $dbh->prepare(q{INSERT INTO org_alias (alias, org_id) VALUES (?,?)});
    # App invariant (Bawi::User::resolve_or_create_org): the canonical name
    # is ALWAYS also an alias — "no alias == invisible org". Keep each name
    # in its list. Names are stored HTML-ESCAPED (house style; org_suggest
    # escapes the query before matching) — org 5 carries a literal & as
    # &amp; to keep that storage class exercised.
    my @ORGS = (        # org_id, canonical name, searchable aliases
        [1, '가상연구소 (Synthetic Labs)', ['가상연구소 (Synthetic Labs)', '가상연구소', 'Synthetic Labs']],
        [2, 'Example Corp',                ['Example Corp', '예제회사']],
        [3, '모의대학병원',                ['모의대학병원']],
        [4, 'Test Foundation',             ['Test Foundation', '테스트재단']],
        [5, 'Example &amp; Sons',          ['Example &amp; Sons', '예제앤선즈']],
    );
    for my $o (@ORGS) {
        my ($oid, $oname, $aliases) = @$o;
        $org->execute($oid, $oname);
        $al->execute($_, $oid) for @$aliases;
    }
    my @ctypes = ('employment','internship','volunteer','research','military','other');
    my $cr = $dbh->prepare(q{
        INSERT INTO bw_user_career
            (career_id, uid, type, organization_id, position, start_date, end_date)
        VALUES (?,?,?,?,?,?,?)});
    my $cid = 0;
    for my $uid (2 .. 25) {              # 24 entries; full type-enum coverage
        $cid++;
        my $start   = BASE_EPOCH - 86400 * 365 * (6 - $uid % 5);
        my $ongoing = $uid % 4 == 0;     # NULL end_date = ongoing
        $cr->execute($cid, $uid, $ctypes[$uid % 6], 1 + ($uid % 5),
                     '합성 직위 (synthetic position)',
                     d($start), $ongoing ? undef : d($start + 86400 * 365 * 2));
    }
    # Edge classes the career UI branches on: unknown start (NULL), a
    # dangling organization_id ('(삭제된 기관)' path), and second careers
    # for uids 2 and 3 (exercises the end_date-DESC ordering).
    $cr->execute(++$cid, 2, 'other', 99, '삭제기관 테스트 (dangling org)',
                 undef, d(BASE_EPOCH - 86400 * 365 * 8));
    $cr->execute(++$cid, 3, 'volunteer', 3, '시작일 미상 (unknown start)',
                 undef, undef);
}

# ------------------------------------------------------------------- loads
{
    my $ld = $dbh->prepare(q{
        INSERT INTO loads (id, one, five, fifteen, online, created_at) VALUES (?,?,?,?,?,?)});
    for my $i (1 .. 24) {
        $ld->execute($i, 0.1 + 0.01 * ($i % 7), 0.2, 0.15, 3 + $i % 9,
                     dt(BASE_EPOCH + 86400 * 500 + 3600 * $i));
    }
}

# --------------------------------------- derived counters (kept consistent)
print "updating derived counters (board/article aggregates, stat tables)\n";
$dbh->do(q{UPDATE bw_xboard_header h
           SET comments = (SELECT COUNT(*) FROM bw_xboard_comment c
                           WHERE c.article_id = h.article_id)});
$dbh->do(q{UPDATE bw_xboard_header h
           SET recom = (SELECT COUNT(*) FROM bw_xboard_recom r
                        WHERE r.article_id = h.article_id)});
$dbh->do(q{UPDATE bw_xboard_board b SET
           articles       = (SELECT COUNT(*)             FROM bw_xboard_header  h WHERE h.board_id = b.board_id),
           max_article_no = (SELECT COALESCE(MAX(h.article_no),0) FROM bw_xboard_header  h WHERE h.board_id = b.board_id),
           max_comment_no = (SELECT COALESCE(MAX(c.comment_no),0) FROM bw_xboard_comment c WHERE c.board_id = b.board_id)});

# stat tables (hot/stat pages) aggregated from the seeded data
$dbh->do(q{INSERT INTO bw_xboard_stat_board (board_id, counts, articles, comments, recoms)
           SELECT board_id, SUM(count), COUNT(*), SUM(comments), SUM(recom)
           FROM bw_xboard_header GROUP BY board_id});
$dbh->do(q{INSERT INTO bw_xboard_stat_article
               (board_id, article_id, title, id, name, count, recom, comments, created, ki)
           SELECT h.board_id, h.article_id, h.title, h.id, h.name,
                  h.count, h.recom, h.comments, h.created, COALESCE(k.ki, 0)
           FROM bw_xboard_header h LEFT JOIN bw_user_ki k ON k.uid = h.uid
           ORDER BY h.recom DESC, h.article_id LIMIT 30});
$dbh->do(q{INSERT INTO bw_xboard_stat_user (id, name, articles, counts, comments, recoms)
           SELECT h.id, h.name, COUNT(*), SUM(h.count), SUM(h.comments), SUM(h.recom)
           FROM bw_xboard_header h GROUP BY h.id, h.name});

# -------------------------------------------------------------- verification
print "\n=== verification ===\n";
for my $t (qw(bw_xauth_passwd bw_user_ki bw_group bw_group_user bw_xboard_board
              bw_xboard_header bw_xboard_body bw_xboard_comment bw_xboard_recom
              bw_xboard_notice bw_xboard_bookmark bw_note bw_xboard_poll
              bw_xboard_poll_opt bw_xboard_poll_ans bw_user_degree registers
              organizations org_alias bw_user_career)) {
    my ($n) = $dbh->selectrow_array("SELECT COUNT(*) FROM $t");
    printf "  %-22s %6d rows\n", $t, $n;
}
my ($login_ok) = $dbh->selectrow_array(
    q{SELECT COUNT(*) FROM bw_xauth_passwd WHERE passwd = ENCRYPT(?, passwd)},
    undef, $TEST_PASSWORD);
print "  users whose password verifies as '$TEST_PASSWORD': $login_ok (expect $N_USERS)\n";
die "FATAL: seeded passwords do not verify\n" unless $login_ok == $N_USERS;

my ($orphan_bodies) = $dbh->selectrow_array(q{
    SELECT COUNT(*) FROM bw_xboard_header h
    LEFT JOIN bw_xboard_body b ON b.article_id = h.article_id
    WHERE b.article_id IS NULL});
print "  headers without body: $orphan_bodies (expect 0)\n";
die "FATAL: headers without bodies\n" if $orphan_bodies;

print "\nseed complete. Log in on this stack's web port (default http://localhost:8080/) as 'root' or 'testuser02' (password: $TEST_PASSWORD)\n";
$dbh->disconnect;
