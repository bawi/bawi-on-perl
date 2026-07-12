-- Render cache for markdown articles (category==1): format_article renders
-- bodies with Bawi::Markdown at READ time, up to ~15 articles per page.
-- This table stores render() output so an unchanged body renders once,
-- not once per view. One row per article (PK), written read-through by
-- Bawi::Board::format_article; no eviction needed.
--
-- body_md5 = md5("<Bawi::Markdown::CACHE_VERSION>:<body bytes>"):
--   * a body edit changes the md5 -> next read misses and REPLACEs the row
--   * a pipeline change is a CACHE_VERSION bump in Bawi/Markdown.pm ->
--     every row goes stale and re-renders lazily on next view
-- html is the PRE-sanitization render (escape_tags + the href strip are
-- applied per-read in format_article, so per-board denylist changes apply
-- immediately). MEDIUMTEXT: entity escaping can push a 64KB body's render
-- past TEXT's 64KB cap. Rows for deleted articles are harmless orphans.

CREATE TABLE bw_xboard_body_html (
  article_id mediumint(8) unsigned NOT NULL,
  body_md5   char(32) NOT NULL,
  html       mediumtext,
  modified   timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (article_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
