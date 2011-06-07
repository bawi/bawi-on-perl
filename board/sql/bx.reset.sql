--
-- Table structure for table `bw_group`
--

DROP TABLE IF EXISTS `bw_group`;
CREATE TABLE `bw_group` (
  `gid` mediumint(8) unsigned NOT NULL auto_increment,
  `pgid` mediumint(8) unsigned NOT NULL default '0',
  `title` varchar(32) NOT NULL default '',
  `keyword` varchar(16) NOT NULL default '',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `type` enum('open','review','closed') NOT NULL default 'open',
  `seq` smallint(5) unsigned NOT NULL default '0',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `g_sub` tinyint(1) NOT NULL default '0',
  `m_sub` tinyint(1) NOT NULL default '0',
  `a_sub` tinyint(1) NOT NULL default '0',
  `g_board` tinyint(1) NOT NULL default '0',
  `m_board` tinyint(1) NOT NULL default '0',
  `a_board` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`gid`,`uid`),
  UNIQUE KEY `keyword` (`keyword`),
  KEY `pgid` (`pgid`),
  KEY `uid` (`uid`)
) TYPE=MyISAM;

INSERT INTO `bw_group` (`title`, `keyword`, `uid`, `created`) VALUES ('BawiX', 'BawiX', 1, NOW());

--
-- Table structure for table `bw_group_user`
--

DROP TABLE IF EXISTS `bw_group_user`;
CREATE TABLE `bw_group_user` (
  `gid` mediumint(8) unsigned NOT NULL default '0',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `status` enum('active','inactive') NOT NULL default 'active',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`gid`,`uid`),
  UNIQUE KEY `user` (`uid`,`gid`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_user_sig`
--

DROP TABLE IF EXISTS `bw_user_sig`;
CREATE TABLE `bw_user_sig` (
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `sig` text NOT NULL,
  PRIMARY KEY  (`uid`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xauth_passwd`
--

DROP TABLE IF EXISTS `bw_xauth_passwd`;
CREATE TABLE `bw_xauth_passwd` (
  `uid` mediumint(8) unsigned NOT NULL auto_increment,
  `id` char(64) binary NOT NULL default '',
  `name` char(32) binary NOT NULL default '',
  `passwd` char(13) NOT NULL default '',
  `email` char(64) NOT NULL default '',
  `modified` datetime NOT NULL default '0000-00-00 00:00:00',
  `accessed` datetime NOT NULL default '0000-00-00 00:00:00',
  `access` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`uid`),
  UNIQUE KEY `id` (`id`),
  KEY `accessed` (`accessed`)
) TYPE=MyISAM;

INSERT INTO `bw_xauth_passwd` (`id`, `name`, `passwd`, `modified`) VALUES ('root', 'root', ENCRYPT('root'), NOW());

--
-- Table structure for table `bw_xauth_session`
--

DROP TABLE IF EXISTS `bw_xauth_session`;
CREATE TABLE `bw_xauth_session` (
  `session_key` char(32) NOT NULL default '',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `id` char(64) binary NOT NULL default '',
  `name` char(32) binary NOT NULL default '',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`session_key`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_attach`
--

DROP TABLE IF EXISTS `bw_xboard_attach`;
CREATE TABLE `bw_xboard_attach` (
  `attach_id` mediumint(8) unsigned NOT NULL auto_increment,
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  `filename` varchar(255) NOT NULL default '',
  `filesize` int(10) unsigned NOT NULL default '0',
  `content_type` varchar(255) NOT NULL default 'application/octet-stream',
  `is_img` enum('y','n') NOT NULL default 'n',
  PRIMARY KEY  (`attach_id`),
  KEY `board_id` (`board_id`,`article_id`),
  KEY `article_id` (`article_id`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_board`
--

DROP TABLE IF EXISTS `bw_xboard_board`;
CREATE TABLE `bw_xboard_board` (
  `board_id` smallint(5) unsigned NOT NULL auto_increment,
  `keyword` varchar(16) NOT NULL default '',
  `gid` mediumint(8) unsigned NOT NULL default '1',
  `title` varchar(32) NOT NULL default '',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `id` varchar(10) binary NOT NULL default '',
  `name` varchar(10) NOT NULL default '',
  `skin` varchar(16) NOT NULL default 'default',
  `article_per_page` tinyint(3) unsigned NOT NULL default '15',
  `page_per_page` tinyint(3) unsigned NOT NULL default '10',
  `sort_list` enum('thread','number') NOT NULL default 'thread',
  `title_length` tinyint(3) unsigned NOT NULL default '50',
  `attach_limit` int(10) unsigned NOT NULL default '307200',
  `image_width` smallint(5) unsigned NOT NULL default '600',
  `thumb_width` tinyint(3) unsigned NOT NULL default '100',
  `thread_spacer` varchar(255) NOT NULL default '&nbsp;&nbsp;&nbsp;',
  `allow_attach` tinyint(1) NOT NULL default '1',
  `allow_recom` tinyint(1) NOT NULL default '1',
  `allow_scrap` tinyint(1) NOT NULL default '1',
  `allow_html` tinyint(1) NOT NULL default '1',
  `allow_category` tinyint(1) NOT NULL default '1',
  `escaped_tags` varchar(255) NOT NULL default 'html body embed iframe applet script bgsound object meta',
  `is_imgboard` tinyint(1) NOT NULL default '0',
  `is_anonboard` tinyint(1) NOT NULL default '0',
  `seq` smallint(5) unsigned NOT NULL default '0',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `articles` mediumint(8) unsigned NOT NULL default '0',
  `images` mediumint(8) unsigned NOT NULL default '0',
  `max_article_no` mediumint(8) unsigned NOT NULL default '0',
  `max_comment_no` mediumint(8) unsigned NOT NULL default '0',
  `g_read` tinyint(1) NOT NULL default '1',
  `m_read` tinyint(1) NOT NULL default '1',
  `a_read` tinyint(1) NOT NULL default '0',
  `g_write` tinyint(1) NOT NULL default '1',
  `m_write` tinyint(1) NOT NULL default '1',
  `a_write` tinyint(1) NOT NULL default '0',
  `g_comment` tinyint(1) NOT NULL default '1',
  `m_comment` tinyint(1) NOT NULL default '1',
  `a_comment` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`board_id`),
  UNIQUE KEY `keyword` (`keyword`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_body`
--

DROP TABLE IF EXISTS `bw_xboard_body`;
CREATE TABLE `bw_xboard_body` (
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `body` text,
  `modified` timestamp NOT NULL,
  PRIMARY KEY  (`article_id`),
  UNIQUE KEY `board` (`board_id`,`article_id`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_bookmark`
--

DROP TABLE IF EXISTS `bw_xboard_bookmark`;
CREATE TABLE `bw_xboard_bookmark` (
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `article_no` mediumint(8) unsigned NOT NULL default '0',
  `comment_no` mediumint(8) unsigned NOT NULL default '0',
  `seq` smallint(5) unsigned NOT NULL default '0',
  PRIMARY KEY  (`uid`,`board_id`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_comment`
--

DROP TABLE IF EXISTS `bw_xboard_comment`;
CREATE TABLE `bw_xboard_comment` (
  `comment_id` mediumint(8) unsigned NOT NULL auto_increment,
  `comment_no` mediumint(8) unsigned NOT NULL default '0',
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  `body` char(200) NOT NULL default '',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `id` char(10) binary NOT NULL default '',
  `name` char(10) NOT NULL default '',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`comment_id`),
  UNIQUE KEY `bookmark` (`board_id`,`comment_no`),
  KEY `article_id` (`article_id`),
  KEY `board` (`board_id`,`article_id`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_header`
--

DROP TABLE IF EXISTS `bw_xboard_header`;
CREATE TABLE `bw_xboard_header` (
  `article_id` mediumint(8) unsigned NOT NULL auto_increment,
  `article_no` mediumint(8) unsigned NOT NULL default '0',
  `parent_no` mediumint(8) unsigned NOT NULL default '0',
  `thread_no` mediumint(8) unsigned NOT NULL default '0',
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `category` tinyint(3) unsigned NOT NULL default '0',
  `title` char(64) NOT NULL default '',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `id` char(10) binary NOT NULL default '',
  `name` char(10) NOT NULL default '',
  `count` smallint(5) unsigned NOT NULL default '0',
  `recom` smallint(5) unsigned NOT NULL default '0',
  `scrap` smallint(5) unsigned NOT NULL default '0',
  `comments` smallint(5) unsigned NOT NULL default '0',
  `has_attach` tinyint(1) NOT NULL default '0',
  `has_poll` tinyint(1) NOT NULL default '0',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`article_id`),
  UNIQUE KEY `a_no` (`board_id`,`article_no`),
  UNIQUE KEY `board` (`board_id`,`article_id`),
  KEY `thread` (`board_id`,`thread_no`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_notice`
--

DROP TABLE IF EXISTS `bw_xboard_notice`;
CREATE TABLE `bw_xboard_notice` (
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`board_id`,`article_id`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_poll`
--

DROP TABLE IF EXISTS `bw_xboard_poll`;
CREATE TABLE `bw_xboard_poll` (
  `poll_id` mediumint(8) unsigned NOT NULL auto_increment,
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  `poll` text NOT NULL,
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  `closed` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`poll_id`),
  KEY `board_id` (`board_id`,`article_id`),
  KEY `article_id` (`article_id`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_poll_ans`
--

DROP TABLE IF EXISTS `bw_xboard_poll_ans`;
CREATE TABLE `bw_xboard_poll_ans` (
  `poll_id` mediumint(8) unsigned NOT NULL default '0',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `opt_id` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`poll_id`,`uid`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_poll_opt`
--

DROP TABLE IF EXISTS `bw_xboard_poll_opt`;
CREATE TABLE `bw_xboard_poll_opt` (
  `opt_id` mediumint(8) unsigned NOT NULL auto_increment,
  `poll_id` mediumint(8) unsigned NOT NULL default '0',
  `opt` text NOT NULL,
  `count` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`opt_id`),
  KEY `poll_id` (`poll_id`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_recom`
--

DROP TABLE IF EXISTS `bw_xboard_recom`;
CREATE TABLE `bw_xboard_recom` (
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`article_id`,`uid`)
) TYPE=MyISAM;

--
-- Table structure for table `bw_xboard_scrap`
--

DROP TABLE IF EXISTS `bw_xboard_scrap`;
CREATE TABLE `bw_xboard_scrap` (
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`uid`,`article_id`)
) TYPE=MyISAM;

DROP TABLE IF EXISTS `bw_xboard_tag`;
CREATE TABLE `bw_xboard_tag` (
  `tag_id` mediumint(8) unsigned NOT NULL auto_increment,
  `tag` varchar(255) NOT NULL default '',
  `count` mediumint(8) unsigned NOT NULL default '0',
  PRIMARY KEY (`tag_id`),
  UNIQUE KEY `tag` (`tag`)
) TYPE=MyISAM;

DROP TABLE IF EXISTS `bw_xboard_tagmap`;
CREATE TABLE `bw_xboard_tagmap` (
  `tagmap_id` mediumint(8) unsigned NOT NULL auto_increment,
  `board_id` smallint(5) unsigned NOT NULL default '0',
  `article_id` mediumint(8) unsigned NOT NULL default '0',
  `uid` mediumint(8) unsigned NOT NULL default '0',
  `tag_id` mediumint(8) unsigned NOT NULL default '0',
  `created` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY (`tagmap_id`),
  UNIQUE KEY `tagmap` (`board_id`,`article_id`,`uid`,`tag_id`)
) TYPE=MyISAM;

