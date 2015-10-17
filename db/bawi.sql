-- MySQL dump 10.13  Distrib 5.5.44, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: bawi
-- ------------------------------------------------------
-- Server version	5.5.44-0ubuntu0.14.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `bawi_access_stat`
--

DROP TABLE IF EXISTS `bawi_access_stat`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bawi_access_stat` (
  `date` date NOT NULL DEFAULT '0000-00-00',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `access` mediumint(8) unsigned NOT NULL DEFAULT '0',
  UNIQUE KEY `date` (`date`,`uid`),
  KEY `uid` (`uid`,`date`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_data_major`
--

DROP TABLE IF EXISTS `bw_data_major`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_data_major` (
  `major_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `major` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`major_id`),
  KEY `parent_id` (`parent_id`)
) ENGINE=MyISAM AUTO_INCREMENT=71 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_group`
--

DROP TABLE IF EXISTS `bw_group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_group` (
  `gid` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `pgid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `title` varchar(32) NOT NULL DEFAULT '',
  `keyword` varchar(16) NOT NULL DEFAULT '',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `type` enum('open','review','closed') NOT NULL DEFAULT 'open',
  `seq` smallint(5) unsigned NOT NULL DEFAULT '0',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `g_sub` tinyint(1) NOT NULL DEFAULT '0',
  `m_sub` tinyint(1) NOT NULL DEFAULT '0',
  `a_sub` tinyint(1) NOT NULL DEFAULT '0',
  `g_board` tinyint(1) NOT NULL DEFAULT '0',
  `m_board` tinyint(1) NOT NULL DEFAULT '0',
  `a_board` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`gid`,`uid`),
  UNIQUE KEY `keyword` (`keyword`),
  KEY `pgid` (`pgid`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM AUTO_INCREMENT=125 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_group_user`
--

DROP TABLE IF EXISTS `bw_group_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_group_user` (
  `gid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `status` enum('active','inactive') NOT NULL DEFAULT 'active',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`gid`,`uid`),
  UNIQUE KEY `user` (`uid`,`gid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_note`
--

DROP TABLE IF EXISTS `bw_note`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_note` (
  `msg_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `to_id` varchar(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `to_name` varchar(16) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `from_id` varchar(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `from_name` varchar(16) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `msg` text NOT NULL,
  `sent_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `read_time` datetime DEFAULT NULL,
  PRIMARY KEY (`msg_id`,`to_id`),
  UNIQUE KEY `msg_id` (`msg_id`),
  KEY `to_id` (`to_id`,`sent_time`,`read_time`) USING BTREE,
  KEY `from_id` (`from_id`,`sent_time`,`read_time`) USING BTREE
) ENGINE=MyISAM AUTO_INCREMENT=1426891 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_note_notify_boxcar`
--

DROP TABLE IF EXISTS `bw_note_notify_boxcar`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_note_notify_boxcar` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `email` varchar(64) NOT NULL DEFAULT '',
  UNIQUE KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_poll`
--

DROP TABLE IF EXISTS `bw_poll`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_poll` (
  `poll_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `gid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `title` varchar(64) NOT NULL DEFAULT '',
  `id` varchar(10) NOT NULL DEFAULT '',
  `name` varchar(10) NOT NULL DEFAULT '',
  `date_s` datetime NOT NULL DEFAULT '1985-03-31 00:00:00',
  `date_e` datetime NOT NULL DEFAULT '1986-04-28 00:00:00',
  `secret` enum('locked','not') NOT NULL DEFAULT 'not',
  `activated` enum('activated','not') NOT NULL DEFAULT 'not',
  `ref_url` varchar(100) NOT NULL DEFAULT '',
  `desc` text NOT NULL,
  PRIMARY KEY (`poll_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_poll_check`
--

DROP TABLE IF EXISTS `bw_poll_check`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_poll_check` (
  `poll_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`poll_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_poll_choice`
--

DROP TABLE IF EXISTS `bw_poll_choice`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_poll_choice` (
  `choice_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `question_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `choice_txt` char(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`choice_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_poll_comment`
--

DROP TABLE IF EXISTS `bw_poll_comment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_poll_comment` (
  `comment_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `poll_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `comment_txt` text,
  `comment_time` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`comment_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_poll_question`
--

DROP TABLE IF EXISTS `bw_poll_question`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_poll_question` (
  `question_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `poll_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `type` enum('multiple','yesno','scale','free') NOT NULL DEFAULT 'free',
  `question_txt` char(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`question_id`),
  KEY `poll_id` (`poll_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_postman_log`
--

DROP TABLE IF EXISTS `bw_postman_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_postman_log` (
  `postman_id` int(7) NOT NULL AUTO_INCREMENT,
  `sender_name` varchar(32) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `sender_email` varchar(64) NOT NULL DEFAULT '',
  `sender_ip` varchar(15) NOT NULL DEFAULT '',
  `sender_org` varchar(255) DEFAULT NULL,
  `bawi_uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `submit_time` datetime DEFAULT NULL,
  PRIMARY KEY (`postman_id`)
) ENGINE=MyISAM AUTO_INCREMENT=117 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_symp`
--

DROP TABLE IF EXISTS `bw_symp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_symp` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `school` varchar(255) NOT NULL DEFAULT '',
  `department` varchar(255) NOT NULL DEFAULT '',
  `field` varchar(255) NOT NULL DEFAULT '',
  `education` text NOT NULL,
  `title` text NOT NULL,
  `abstract` text NOT NULL,
  `reference` text NOT NULL,
  `count` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_access`
--

DROP TABLE IF EXISTS `bw_user_access`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_access` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `id` varchar(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `last_access` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `count` int(11) DEFAULT NULL,
  PRIMARY KEY (`uid`),
  KEY `time_index` (`last_access`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_access_history`
--

DROP TABLE IF EXISTS `bw_user_access_history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_access_history` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `last_access` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `id` varchar(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `count` int(11) DEFAULT NULL,
  PRIMARY KEY (`uid`,`last_access`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_basic`
--

DROP TABLE IF EXISTS `bw_user_basic`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_basic` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `ename` varchar(96) NOT NULL DEFAULT '',
  `homepage` varchar(192) NOT NULL DEFAULT '',
  `im_msn` varchar(192) NOT NULL DEFAULT '',
  `im_yahoo` varchar(192) NOT NULL DEFAULT '',
  `im_nate` varchar(192) NOT NULL DEFAULT '',
  `im_google` varchar(192) NOT NULL DEFAULT '',
  `mobile_tel` varchar(96) NOT NULL DEFAULT '',
  `birth` date NOT NULL DEFAULT '0000-00-00',
  `death` date NOT NULL DEFAULT '0000-00-00',
  `wedding` date NOT NULL DEFAULT '0000-00-00',
  `home_address` text NOT NULL,
  `home_map` text NOT NULL,
  `home_tel` varchar(96) NOT NULL DEFAULT '',
  `affiliation` varchar(384) NOT NULL DEFAULT '',
  `title` varchar(192) NOT NULL DEFAULT '',
  `office_address` text NOT NULL,
  `office_map` text NOT NULL,
  `office_tel` varchar(96) NOT NULL DEFAULT '',
  `temp_address` text NOT NULL,
  `temp_map` text NOT NULL,
  `temp_tel` varchar(96) NOT NULL DEFAULT '',
  `greeting` varchar(765) NOT NULL DEFAULT '',
  `class1` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `class2` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `class3` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `count` int(10) unsigned NOT NULL DEFAULT '0',
  `count_today` int(10) unsigned NOT NULL DEFAULT '0',
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `twitter` varchar(16) NOT NULL,
  `facebook` varchar(192) NOT NULL,
  UNIQUE KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_circle`
--

DROP TABLE IF EXISTS `bw_user_circle`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_circle` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `circle_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`circle_id`,`uid`),
  UNIQUE KEY `uid` (`uid`,`circle_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_degree`
--

DROP TABLE IF EXISTS `bw_user_degree`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_degree` (
  `degree_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `type` enum('Bachelor','Master','Doctor') NOT NULL DEFAULT 'Bachelor',
  `school_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `department` varchar(255) NOT NULL DEFAULT '',
  `advisors` varchar(255) NOT NULL DEFAULT '',
  `content` text NOT NULL,
  `start_date` date NOT NULL DEFAULT '0000-00-00',
  `end_date` date NOT NULL DEFAULT '0000-00-00',
  `status` varchar(20) NOT NULL,
  PRIMARY KEY (`degree_id`),
  KEY `uid` (`uid`),
  KEY `school_id` (`school_id`)
) ENGINE=MyISAM AUTO_INCREMENT=6115 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_gbook`
--

DROP TABLE IF EXISTS `bw_user_gbook`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_gbook` (
  `gbook_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `guest_uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `body` text NOT NULL,
  `reply` text NOT NULL,
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`gbook_id`),
  KEY `uid` (`uid`),
  KEY `guest_uid` (`guest_uid`),
  KEY `created` (`created`)
) ENGINE=MyISAM AUTO_INCREMENT=323086 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_ki`
--

DROP TABLE IF EXISTS `bw_user_ki`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_ki` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `ki` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`),
  KEY `ki` (`ki`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_major`
--

DROP TABLE IF EXISTS `bw_user_major`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_major` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `major_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`major_id`,`uid`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_photo`
--

DROP TABLE IF EXISTS `bw_user_photo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_photo` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `photo` blob NOT NULL,
  `thumb` blob NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_sig`
--

DROP TABLE IF EXISTS `bw_user_sig`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_sig` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `sig` text NOT NULL,
  PRIMARY KEY (`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_user_support`
--

DROP TABLE IF EXISTS `bw_user_support`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_user_support` (
  `ipgumdt` date NOT NULL DEFAULT '0000-00-00',
  `email` varchar(50) DEFAULT NULL,
  `name` varchar(20) DEFAULT NULL,
  `amount` int(11) DEFAULT NULL,
  `fee` int(11) DEFAULT NULL,
  `realamount` int(11) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `paymenttype` varchar(20) DEFAULT NULL,
  `bawiid` varchar(12) NOT NULL DEFAULT '',
  PRIMARY KEY (`bawiid`,`ipgumdt`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xauth_new_passwd`
--

DROP TABLE IF EXISTS `bw_xauth_new_passwd`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xauth_new_passwd` (
  `no` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `id` varchar(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` varchar(32) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `passwd` varchar(13) NOT NULL DEFAULT '',
  `email` varchar(64) NOT NULL DEFAULT '',
  `birth` date NOT NULL DEFAULT '0000-00-00',
  `ki` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `affiliation` varchar(64) NOT NULL DEFAULT '',
  `recom_id` varchar(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `recom_passwd` varchar(8) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `status` enum('applied','recommended','rejected','ignored','done') NOT NULL DEFAULT 'applied',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`no`),
  UNIQUE KEY `id` (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1758 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xauth_passwd`
--

DROP TABLE IF EXISTS `bw_xauth_passwd`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xauth_passwd` (
  `uid` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `id` char(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` char(32) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `passwd` char(13) NOT NULL DEFAULT '',
  `email` char(64) NOT NULL DEFAULT '',
  `modified` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `accessed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `access` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`),
  UNIQUE KEY `id` (`id`),
  KEY `accessed` (`accessed`)
) ENGINE=MyISAM AUTO_INCREMENT=17378 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xauth_session`
--

DROP TABLE IF EXISTS `bw_xauth_session`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xauth_session` (
  `session_key` char(32) NOT NULL DEFAULT '',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `id` char(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` char(32) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`session_key`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_attach`
--

DROP TABLE IF EXISTS `bw_xboard_attach`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_attach` (
  `attach_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `filename` varchar(255) NOT NULL DEFAULT '',
  `filesize` int(10) unsigned NOT NULL DEFAULT '0',
  `content_type` varchar(255) NOT NULL DEFAULT 'application/octet-stream',
  `is_img` enum('y','n') NOT NULL DEFAULT 'n',
  `width` smallint(6) NOT NULL DEFAULT '0',
  `height` smallint(6) NOT NULL DEFAULT '0',
  PRIMARY KEY (`attach_id`),
  KEY `board_id` (`board_id`,`article_id`),
  KEY `article_id` (`article_id`)
) ENGINE=MyISAM AUTO_INCREMENT=253977 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_board`
--

DROP TABLE IF EXISTS `bw_xboard_board`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_board` (
  `board_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `keyword` varchar(16) NOT NULL DEFAULT '',
  `gid` mediumint(8) unsigned NOT NULL DEFAULT '1',
  `title` varchar(32) NOT NULL DEFAULT '',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `id` varchar(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` varchar(10) NOT NULL DEFAULT '',
  `skin` varchar(16) NOT NULL DEFAULT 'default',
  `article_per_page` tinyint(3) unsigned NOT NULL DEFAULT '15',
  `page_per_page` tinyint(3) unsigned NOT NULL DEFAULT '10',
  `sort_list` enum('thread','number') NOT NULL DEFAULT 'thread',
  `title_length` tinyint(3) unsigned NOT NULL DEFAULT '50',
  `attach_limit` int(10) unsigned NOT NULL DEFAULT '307200',
  `image_width` smallint(5) unsigned NOT NULL DEFAULT '600',
  `thumb_width` tinyint(3) unsigned NOT NULL DEFAULT '100',
  `thread_spacer` varchar(255) NOT NULL DEFAULT '&nbsp;&nbsp;&nbsp;',
  `allow_attach` tinyint(1) NOT NULL DEFAULT '1',
  `allow_recom` tinyint(1) NOT NULL DEFAULT '1',
  `allow_scrap` tinyint(1) NOT NULL DEFAULT '1',
  `allow_html` tinyint(1) NOT NULL DEFAULT '1',
  `allow_category` tinyint(1) NOT NULL DEFAULT '1',
  `escaped_tags` varchar(255) NOT NULL DEFAULT 'html body embed iframe applet script bgsound object meta',
  `is_imgboard` tinyint(1) NOT NULL DEFAULT '0',
  `is_anonboard` tinyint(1) NOT NULL DEFAULT '0',
  `seq` smallint(5) unsigned NOT NULL DEFAULT '0',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `articles` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `images` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `max_article_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `max_comment_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `g_read` tinyint(1) NOT NULL DEFAULT '1',
  `m_read` tinyint(1) NOT NULL DEFAULT '1',
  `a_read` tinyint(1) NOT NULL DEFAULT '0',
  `g_write` tinyint(1) NOT NULL DEFAULT '1',
  `m_write` tinyint(1) NOT NULL DEFAULT '1',
  `a_write` tinyint(1) NOT NULL DEFAULT '0',
  `g_comment` tinyint(1) NOT NULL DEFAULT '1',
  `m_comment` tinyint(1) NOT NULL DEFAULT '1',
  `a_comment` tinyint(1) NOT NULL DEFAULT '0',
  `g_tag` tinyint(1) NOT NULL DEFAULT '1',
  `m_tag` tinyint(1) NOT NULL DEFAULT '1',
  `a_tag` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`board_id`),
  UNIQUE KEY `keyword` (`keyword`)
) ENGINE=MyISAM AUTO_INCREMENT=3412 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_body`
--

DROP TABLE IF EXISTS `bw_xboard_body`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_body` (
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `body` text,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`article_id`),
  UNIQUE KEY `board` (`board_id`,`article_id`),
  FULLTEXT KEY `body` (`body`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_bookmark`
--

DROP TABLE IF EXISTS `bw_xboard_bookmark`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_bookmark` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `article_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `comment_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `seq` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`uid`,`board_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_comment`
--

DROP TABLE IF EXISTS `bw_xboard_comment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_comment` (
  `comment_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `comment_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `body` text,
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `id` varchar(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` varchar(10) NOT NULL DEFAULT '',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`comment_id`),
  UNIQUE KEY `bookmark` (`board_id`,`comment_no`),
  KEY `article_id` (`article_id`),
  KEY `board` (`board_id`,`article_id`),
  KEY `uid` (`uid`)
) ENGINE=MyISAM AUTO_INCREMENT=4790099 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_header`
--

DROP TABLE IF EXISTS `bw_xboard_header`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_header` (
  `article_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `article_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `parent_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `thread_no` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `category` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `title` char(64) NOT NULL DEFAULT '',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `id` char(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` char(10) NOT NULL DEFAULT '',
  `count` smallint(5) unsigned NOT NULL DEFAULT '0',
  `recom` smallint(5) unsigned NOT NULL DEFAULT '0',
  `scrap` smallint(5) unsigned NOT NULL DEFAULT '0',
  `comments` smallint(5) unsigned NOT NULL DEFAULT '0',
  `has_attach` tinyint(1) NOT NULL DEFAULT '0',
  `has_poll` tinyint(1) NOT NULL DEFAULT '0',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`article_id`),
  UNIQUE KEY `article_no` (`board_id`,`article_no`) USING BTREE,
  KEY `board_id` (`board_id`) USING HASH,
  KEY `thread_no` (`board_id`,`thread_no`) USING BTREE,
  KEY `created` (`created`) USING BTREE,
  KEY `uid` (`uid`),
  FULLTEXT KEY `title` (`title`)
) ENGINE=MyISAM AUTO_INCREMENT=1639372 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_notice`
--

DROP TABLE IF EXISTS `bw_xboard_notice`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_notice` (
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`board_id`,`article_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_poll`
--

DROP TABLE IF EXISTS `bw_xboard_poll`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_poll` (
  `poll_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `poll` text NOT NULL,
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `closed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`poll_id`),
  KEY `board_id` (`board_id`,`article_id`),
  KEY `article_id` (`article_id`)
) ENGINE=MyISAM AUTO_INCREMENT=9010 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_poll_ans`
--

DROP TABLE IF EXISTS `bw_xboard_poll_ans`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_poll_ans` (
  `poll_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `opt_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`poll_id`,`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_poll_opt`
--

DROP TABLE IF EXISTS `bw_xboard_poll_opt`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_poll_opt` (
  `opt_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `poll_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `opt` text NOT NULL,
  `count` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`opt_id`),
  KEY `poll_id` (`poll_id`)
) ENGINE=MyISAM AUTO_INCREMENT=43352 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_recom`
--

DROP TABLE IF EXISTS `bw_xboard_recom`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_recom` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`article_id`,`uid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_scrap`
--

DROP TABLE IF EXISTS `bw_xboard_scrap`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_scrap` (
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `last_comment_no` mediumint(8) unsigned DEFAULT NULL,
  `scrapped` datetime DEFAULT NULL,
  PRIMARY KEY (`uid`,`article_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_stat_article`
--

DROP TABLE IF EXISTS `bw_xboard_stat_article`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_stat_article` (
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `title` char(64) NOT NULL DEFAULT '',
  `id` char(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` char(10) NOT NULL DEFAULT '',
  `count` smallint(5) unsigned NOT NULL DEFAULT '0',
  `recom` smallint(5) unsigned NOT NULL DEFAULT '0',
  `comments` smallint(5) unsigned NOT NULL DEFAULT '0',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `ki` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`article_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_stat_board`
--

DROP TABLE IF EXISTS `bw_xboard_stat_board`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_stat_board` (
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `counts` smallint(5) unsigned NOT NULL DEFAULT '0',
  `articles` smallint(5) unsigned NOT NULL DEFAULT '0',
  `comments` smallint(5) unsigned NOT NULL DEFAULT '0',
  `recoms` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`board_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_stat_user`
--

DROP TABLE IF EXISTS `bw_xboard_stat_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_stat_user` (
  `id` char(10) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `name` char(10) NOT NULL DEFAULT '',
  `articles` smallint(5) unsigned NOT NULL DEFAULT '0',
  `counts` smallint(5) unsigned NOT NULL DEFAULT '0',
  `comments` smallint(5) unsigned NOT NULL DEFAULT '0',
  `recoms` smallint(5) unsigned NOT NULL DEFAULT '0',
  KEY `user_id` (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_tag`
--

DROP TABLE IF EXISTS `bw_xboard_tag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_tag` (
  `tag_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `tag` varchar(255) NOT NULL DEFAULT '',
  `count` mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`tag_id`),
  UNIQUE KEY `tag` (`tag`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xboard_tagmap`
--

DROP TABLE IF EXISTS `bw_xboard_tagmap`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xboard_tagmap` (
  `tagmap_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `board_id` smallint(5) unsigned NOT NULL DEFAULT '0',
  `article_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `uid` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `tag_id` mediumint(8) unsigned NOT NULL DEFAULT '0',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`tagmap_id`),
  UNIQUE KEY `tagmap` (`board_id`,`article_id`,`uid`,`tag_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xpoll`
--

DROP TABLE IF EXISTS `bw_xpoll`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xpoll` (
  `poll_id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` varchar(11) NOT NULL DEFAULT '',
  `name` varchar(11) NOT NULL DEFAULT '',
  `dt_start` date NOT NULL DEFAULT '0000-00-00',
  `dt_end` date NOT NULL DEFAULT '0000-00-00',
  `opt_hide` smallint(6) NOT NULL DEFAULT '0',
  `numofq` smallint(6) NOT NULL DEFAULT '0',
  `poll_title` varchar(100) NOT NULL DEFAULT '',
  `poll_txt` text NOT NULL,
  `lk` smallint(6) NOT NULL DEFAULT '0',
  `participant` int(11) NOT NULL DEFAULT '0',
  `id` varchar(11) NOT NULL DEFAULT '',
  `poll_comment` text NOT NULL,
  PRIMARY KEY (`poll_id`),
  UNIQUE KEY `poll_title` (`poll_title`),
  UNIQUE KEY `xpoll` (`poll_title`),
  KEY `poll_id` (`poll_id`)
) ENGINE=MyISAM AUTO_INCREMENT=76 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xpoll_check`
--

DROP TABLE IF EXISTS `bw_xpoll_check`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xpoll_check` (
  `poll_id` int(11) NOT NULL DEFAULT '0',
  `uid` int(11) NOT NULL DEFAULT '0'
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xpoll_choice`
--

DROP TABLE IF EXISTS `bw_xpoll_choice`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xpoll_choice` (
  `choice_id` int(11) NOT NULL AUTO_INCREMENT,
  `question_id` int(11) NOT NULL DEFAULT '0',
  `choice_txt` varchar(100) NOT NULL DEFAULT '',
  `choice_count` int(11) NOT NULL DEFAULT '0',
  `choice_q` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`choice_id`),
  KEY `choice_id` (`choice_id`)
) ENGINE=MyISAM AUTO_INCREMENT=411 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `bw_xpoll_question`
--

DROP TABLE IF EXISTS `bw_xpoll_question`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bw_xpoll_question` (
  `question_id` int(11) NOT NULL AUTO_INCREMENT,
  `question_txt` varchar(100) NOT NULL DEFAULT '',
  `poll_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`question_id`),
  KEY `quetion_id` (`question_id`)
) ENGINE=MyISAM AUTO_INCREMENT=1402 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `circles`
--

DROP TABLE IF EXISTS `circles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `circles` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=74 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `countries`
--

DROP TABLE IF EXISTS `countries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `countries` (
  `id` int(10) unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL DEFAULT '',
  `code` varchar(2) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `code` (`code`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary table structure for view `freq_bookmark`
--

DROP TABLE IF EXISTS `freq_bookmark`;
/*!50001 DROP VIEW IF EXISTS `freq_bookmark`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `freq_bookmark` (
  `count` tinyint NOT NULL,
  `uid` tinyint NOT NULL
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `loads`
--

DROP TABLE IF EXISTS `loads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `loads` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `one` float NOT NULL DEFAULT '0',
  `five` float NOT NULL DEFAULT '0',
  `fifteen` float NOT NULL DEFAULT '0',
  `online` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `majors`
--

DROP TABLE IF EXISTS `majors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `majors` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` int(10) unsigned NOT NULL DEFAULT '0',
  `name` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `parent_id` (`parent_id`)
) ENGINE=MyISAM AUTO_INCREMENT=70 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notes`
--

DROP TABLE IF EXISTS `notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notes` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `from_id` int(10) unsigned NOT NULL DEFAULT '0',
  `to_id` int(10) unsigned NOT NULL DEFAULT '0',
  `message` text NOT NULL,
  `created_at` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `read_at` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`),
  KEY `from_id` (`from_id`),
  KEY `to_id` (`to_id`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `registers`
--

DROP TABLE IF EXISTS `registers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `registers` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `ki` int(10) unsigned NOT NULL DEFAULT '0',
  `name` varchar(16) DEFAULT NULL,
  `born_on` date NOT NULL DEFAULT '0000-00-00',
  `died_on` date NOT NULL DEFAULT '0000-00-00',
  `category` enum('졸업','수료','조졸','전학','자퇴','재학','기타') NOT NULL DEFAULT '재학',
  `remarks` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `ki` (`ki`,`name`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=4290 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `schools`
--

DROP TABLE IF EXISTS `schools`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `schools` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `full_name` varchar(128) NOT NULL DEFAULT '',
  `brief_name` varchar(32) NOT NULL DEFAULT '',
  `url` varchar(64) DEFAULT NULL,
  `country_code` varchar(2) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `full_name` (`full_name`),
  KEY `brief_name` (`brief_name`)
) ENGINE=MyISAM AUTO_INCREMENT=184 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Final view structure for view `freq_bookmark`
--

/*!50001 DROP TABLE IF EXISTS `freq_bookmark`*/;
/*!50001 DROP VIEW IF EXISTS `freq_bookmark`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8 */;
/*!50001 SET character_set_results     = utf8 */;
/*!50001 SET collation_connection      = utf8_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`bawi`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `freq_bookmark` AS select count(0) AS `count`,`bw_xboard_bookmark`.`uid` AS `uid` from `bw_xboard_bookmark` group by `bw_xboard_bookmark`.`uid` order by count(0) desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2015-10-18  4:48:27
