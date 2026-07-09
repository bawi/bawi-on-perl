-- The PR#4-era table (created 2026-07-06 on prod, never went live, no real
-- data) is a different shape — drop it before creating the v3.2 tables.
DROP TABLE IF EXISTS bw_user_career;

CREATE TABLE organizations (
  org_id       int unsigned NOT NULL AUTO_INCREMENT,
  name         varchar(128) NOT NULL DEFAULT '',   -- canonical display name
  created_by   mediumint unsigned NOT NULL DEFAULT 0,
  created_date timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (org_id),
  KEY name (name)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;   -- utf8_general_ci: case-insensitive alias search

CREATE TABLE org_alias (
  alias  varchar(128) NOT NULL DEFAULT '',   -- every searchable name, incl. the canonical
  org_id int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (alias, org_id),
  KEY org_id (org_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE bw_user_career (
  career_id       mediumint unsigned NOT NULL AUTO_INCREMENT,
  uid             mediumint unsigned NOT NULL DEFAULT 0,
  type            enum('employment','internship','volunteer','research','military','other')
                    NOT NULL DEFAULT 'employment',
  organization_id int unsigned NOT NULL DEFAULT 0,
  position        varchar(255) NOT NULL DEFAULT '',
  start_date      date DEFAULT NULL,   -- NULL = unknown
  end_date        date DEFAULT NULL,   -- NULL = ongoing (multiple NULLs per uid allowed)
  PRIMARY KEY (career_id),
  KEY uid (uid),
  KEY organization_id (organization_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
