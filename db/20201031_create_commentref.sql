CREATE TABLE `bw_xboard_commentref` (
    `commentref_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
    `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
    `comment_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
    `comment_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
    `ref_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
    `ref_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
    UNIQUE KEY `bookmark` (`board_id`,`comment_id`,`ref_id`),
    KEY `article_id` (`article_id`),
    KEY `board` (`board_id`,`article_id`),
    INDEX `lookup` (`board_id`,`comment_no`),
    INDEX `lookup2` (`board_id`,`ref_no`)
) Engine=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
