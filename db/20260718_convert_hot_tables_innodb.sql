-- Convert the HOT tables from MyISAM to InnoDB.
--
-- WHY
--   Every table below sits on the request path, and several are WRITTEN on
--   the READ path: bw_xboard_header takes count=count+1 on every article
--   view, bw_xauth_passwd takes accessed/access on every authenticated
--   request, bw_xboard_board takes max_*_no on every post/comment,
--   bw_xboard_bookmark on every "read new". Under MyISAM each of those
--   UPDATEs takes a TABLE lock: one write blocks every concurrent reader of
--   that table, so under load reads queue behind counter writes on the
--   hottest tables (bw_xboard_comment holds ~4.5M rows, header ~1.6M).
--   InnoDB takes row locks instead, and recovers after a crash on its own --
--   a mod_perl worker killed mid-write leaves a MyISAM table "marked as
--   crashed" needing a manual REPAIR TABLE (with Bawi::DBI running without
--   RaiseError, that failure mode is silent; see the bw_xboard_body_html
--   migration header for the same argument).
--
-- SCOPE
--   Hot set only. Cold/append-only MyISAM tables (bw_note, bw_user_gbook,
--   stat tables, polls, ...) stay as they are -- convert opportunistically
--   later if wanted; nothing in the app depends on engine uniformity.
--
-- ORDERING (fast, small tables first -- each ALTER is independent; the file
--   can be applied in one shot in a maintenance window, or table-by-table):
--     bw_xauth_session, bw_xboard_bookmark, bw_xboard_board   (tiny; seconds)
--     bw_xauth_passwd                                          (small)
--     bw_xboard_commentref                                     (medium)
--     bw_xboard_header                                         (~1.6M rows)
--     bw_xboard_comment                                        (~4.5M rows + TEXT)
--     bw_xboard_body    (~240K rows, TEXT + FULLTEXT: the slow one -- the
--                        FULLTEXT rebuild dominates its copy time)
--
-- PROD PROCEDURE / DOWNTIME
--   ALTER ... ENGINE=InnoDB is ALGORITHM=COPY, LOCK=SHARED on MariaDB 10.6:
--   concurrent READS keep working during the copy, WRITES to that table
--   block. Practical downtime is therefore "writes to one table at a time",
--   longest for comment/body. Before running on prod:
--     1. Time this exact file against a restored prod snapshot on comparable
--        disk (the only trustworthy duration estimate).
--     2. Size the buffer pool FIRST. MyISAM leaned on key_buffer + OS page
--        cache; InnoDB caches data+indexes in its buffer pool. Budget at
--        least the sum reported by:
--          SELECT round(sum(data_length+index_length)/1024/1024) AS mb
--          FROM information_schema.tables WHERE table_schema='bawi'
--          AND table_name IN ('bw_xauth_session','bw_xboard_bookmark',
--            'bw_xboard_board','bw_xauth_passwd','bw_xboard_commentref',
--            'bw_xboard_header','bw_xboard_comment','bw_xboard_body');
--        then set innodb_buffer_pool_size (server restart) and shrink
--        key_buffer_size once conversion is done.
--     3. Run during the nightly low-traffic window; apply table-by-table if
--        the snapshot timing says comment/body need their own windows.
--   Rollback: ALTER TABLE ... ENGINE=MyISAM (same copy cost), or restore
--   from backup. Nothing else in this migration to unwind.
--
-- FULLTEXT
--   bw_xboard_body(body) and bw_xboard_header(title) carry FULLTEXT indexes
--   used by main/search2.cgi (MATCH ... AGAINST). MariaDB 10.6 InnoDB
--   supports FULLTEXT; the ALTER rebuilds them. One behavior delta:
--   InnoDB's innodb_ft_min_token_size defaults to 3 where MyISAM's
--   ft_min_word_len defaults to 4, so 3-char tokens (many meaningful short
--   Korean words) become searchable after conversion. That is a recall
--   IMPROVEMENT, so we deliberately keep the default; for strict parity set
--   innodb_ft_min_token_size=4 (server restart) before converting. InnoDB
--   also uses its own (smaller, English) default stopword list -- irrelevant
--   for Korean content.
--
-- APP BEHAVIOR NOTES (no code changes required)
--   - DBI runs autocommit=1; every statement stays its own transaction.
--   - add_article still does LOCK TABLES head/body/board/bookmark WRITE;
--     that is legal on InnoDB (takes InnoDB table locks for the section) and
--     keeps article creation serialized exactly as today. Fine: creation is
--     rare next to reads, which is where the row-lock win is.
--   - MyISAM's free COUNT(*) goes away: main/news.cgi's two whole-table
--     COUNT(*) vanity stats are swapped to O(#boards) counter sums in the
--     same PR as this migration. No other whole-table COUNT(*) exists on a
--     request path (checked admin/, board/, main/, user/, reg/).
--   - Zero datetime defaults ('0000-00-00') are accepted by the default
--     MariaDB 10.6 sql_mode (NO_ZERO_DATE not set); the ALTER preserves them.

ALTER TABLE bw_xauth_session    ENGINE=InnoDB;
ALTER TABLE bw_xboard_bookmark  ENGINE=InnoDB;
ALTER TABLE bw_xboard_board     ENGINE=InnoDB;
ALTER TABLE bw_xauth_passwd     ENGINE=InnoDB;
ALTER TABLE bw_xboard_commentref ENGINE=InnoDB;
ALTER TABLE bw_xboard_header    ENGINE=InnoDB;
ALTER TABLE bw_xboard_comment   ENGINE=InnoDB;
ALTER TABLE bw_xboard_body      ENGINE=InnoDB;
