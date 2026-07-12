-- Render cache for markdown articles (category==1): format_article renders
-- bodies with Bawi::Markdown at READ time, up to ~15 articles per page.
-- This table stores render() output so an unchanged body renders once,
-- not once per view. One row per article (PK), written read-through by
-- Bawi::Board::format_article; no eviction needed.
--
-- Validity model (canonical statement + CACHE_VERSION bump rule live at
-- Bawi::Markdown::cache_key): body_md5 = cache_key(body). Article
-- deletion is a soft delete (the body becomes a tombstone string), so on
-- the next view the md5 mismatches and the row is overwritten in place --
-- rows are never orphaned, and article_id is AUTO_INCREMENT so ids are
-- never reused.
--
-- html is the PRE-sanitization render (escape_tags + the href strip are
-- applied per-read in format_article, so per-board denylist changes apply
-- immediately). MEDIUMTEXT: entity escaping can push a 64KB body's render
-- past TEXT's 64KB cap.
--
-- InnoDB, unlike the MyISAM content siblings: this table is WRITTEN on
-- the read path (REPLACE per miss), and a mod_perl worker killed mid-write
-- would leave a MyISAM table "marked as crashed" -- with no RaiseError in
-- Bawi::DBI that failure is silent, so the cache would quietly disable
-- itself site-wide until a manual REPAIR TABLE. InnoDB recovers on its
-- own and takes row locks instead of table locks during re-render bursts
-- after a CACHE_VERSION bump.
--
-- CHARSET must track bw_xboard_body's: a future utf8 -> utf8mb4 migration
-- of the body table must include this table, or 4-byte characters in
-- bodies would silently truncate the cached render.

CREATE TABLE bw_xboard_body_html (
  article_id mediumint(8) unsigned NOT NULL,
  body_md5   char(32) NOT NULL,
  html       mediumtext,
  modified   timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (article_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
