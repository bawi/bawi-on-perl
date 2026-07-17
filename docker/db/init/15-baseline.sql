-- Pre-recorded migration state for the schema dump in 10-schema.sql.
--
-- Every db/YYYYMMDD_*.sql migration whose change is ALREADY CONTAINED in that
-- dump must have a 'baseline' row here, so 20-apply-migrations.sh skips it
-- instead of re-executing it (which would abort first-boot init, e.g. on a
-- duplicate CREATE TABLE).
--
-- REGENERATE THIS LIST WHENEVER 10-schema.sql IS REFRESHED: add a baseline
-- row for every dated migration the new dump now includes. The current dump
-- (prod, 2026-07-06, structure only) predates the career-v3.2 and body_html
-- migrations, so those two are NOT baselined and execute on first init.
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   varchar(128) NOT NULL,
  status     enum('applied','baseline') NOT NULL,
  applied_at datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (filename)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO schema_migrations (filename, status) VALUES
  ('20161225_add_career_enum.sql',                   'baseline'),
  ('20201030_add_expiration_days.sql',               'baseline'),
  ('20201031_create_commentref.sql',                 'baseline'),
  ('20220903_add_retraction.sql',                    'baseline'),
  ('20221221_retroactive_change_delete_comment.sql', 'baseline');
