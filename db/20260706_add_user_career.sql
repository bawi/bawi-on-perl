CREATE TABLE `bw_user_career` (
  `career_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint(8) unsigned NOT NULL DEFAULT 0,
  `company` varchar(255) NOT NULL DEFAULT '',
  `position` varchar(255) NOT NULL DEFAULT '',
  `content` text NOT NULL,
  `start_date` date NOT NULL DEFAULT '1001-01-01',
  `end_date` date NOT NULL DEFAULT '1001-01-01',
  PRIMARY KEY (`career_id`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci
