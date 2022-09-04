package Bawi::Board;
use strict;
use warnings;
use Carp;
use File::Spec;
use Bawi::DBI;
use Bawi::Board::Config;

use vars qw(%CONF $DBH %TBL);
$TBL{head}      = 'bw_xboard_header';
$TBL{body}      = 'bw_xboard_body';
$TBL{board}     = 'bw_xboard_board';
$TBL{comment}   = 'bw_xboard_comment';
$TBL{commentref}= 'bw_xboard_commentref';
$TBL{recom}     = 'bw_xboard_recom';
$TBL{scrap}     = 'bw_xboard_scrap';
$TBL{bookmark}  = 'bw_xboard_bookmark';
$TBL{attach}    = 'bw_xboard_attach';
$TBL{notice}    = 'bw_xboard_notice';
$TBL{passwd}    = 'bw_xauth_passwd';
$TBL{sig}       = 'bw_user_sig';
$TBL{group}     = 'bw_group';
$TBL{poll}      = 'bw_xboard_poll';
$TBL{opt}       = 'bw_xboard_poll_opt';
$TBL{ans}       = 'bw_xboard_poll_ans';

sub new {
    my ($class, %arg) = @_;

    my $cfg = $arg{-cfg} || new Bawi::Board::Config(%arg);
    $DBH = $arg{-dbh} || new Bawi::DBI(-cfg=>$cfg);

    my $self; 
    if (exists $arg{-board_id} && defined $arg{-board_id} 
            && $arg{-board_id} =~ /^\d+$/ ) {
        my $img = $arg{-img} || '';
        my $keyword = $arg{-keyword} || '';
        my $field = $arg{-field} || '';
        $self = &init_board(%arg);
    } elsif (exists $arg{-uid} && defined $arg{-uid} && $arg{-uid} =~ /^\d+$/) {
        $self = &init_scrap_board(%arg);
    }
    $$self{cfg} = $cfg;
    $$self{session_key} = $arg{-session_key} if ($arg{-session_key});
    bless $self, $class;
    return $self;
}

sub DESTROY {
    my ($self, %arg) = @_;
    $DBH->disconnect;
}


################################################################################
# accessor


sub cfg {
    my $self = shift;
    if (@_) { $self->{cfg} = shift }
    return $self->{cfg};
}

sub dbh {
    my $self = shift;
    if (@_) { $self->{dbh} = shift }
    return $self->{dbh};
}

sub session_key {
    my $self = shift;
    if (@_) { $self->{session_key} = shift }
    return $self->{session_key};
}

sub board_id {
    my $self = shift;
    if (@_) { $self->{board_id} = shift }
    return $self->{board_id};
}

sub keyword {
    my $self = shift;
    if (@_) { $self->{keyword} = shift }
    return $self->{keyword};
}

sub seq {
    my $self = shift;
    if (@_) { $self->{seq} = shift }
    return $self->{seq};
}

sub gid {
    my $self = shift;
    if (@_) { $self->{gid} = shift }
    return $self->{gid};
}

sub title {
    my $self = shift;
    if (@_) { $self->{title} = shift }
    return $self->{title};
}

sub uid {
    my $self = shift;
    if (@_) { $self->{uid} = shift }
    return $self->{uid};
}

sub id {
    my $self = shift;
    if (@_) { $self->{id} = shift }
    return $self->{id};
}

sub name {
    my $self = shift;
    if (@_) { $self->{name} = shift }
    return $self->{name};
}

sub skin {
    my $self = shift;
    if (@_) { $self->{skin} = shift }
    return $self->{skin};
}

sub expire_days {
    my $self = shift;
    if (@_) { $self->{expire_days} = shift }
    return $self->{expire_days};
}

sub article_per_page {
    my $self = shift;
    if (@_) { $self->{article_per_page} = shift }
    return $self->{article_per_page};
}

sub page_per_page {
    my $self = shift;
    if (@_) { $self->{page_per_page} = shift }
    return $self->{page_per_page};
}

sub title_length {
    my $self = shift;
    if (@_) { $self->{title_length} = shift }
    return $self->{title_length};
}

sub attach_limit {
    my $self = shift;
    if (@_) { $self->{attach_limit} = shift }
    return $self->{attach_limit};
}

sub attach_limit_bytes {
    my $self = shift;
    if (@_) { $self->{attach_limit} = shift }
    return &bytes($self->{attach_limit});
}

sub image_width {
    my $self = shift;
    if (@_) { $self->{image_width} = shift }
    return $self->{image_width};
}

sub thumb_width {
    my $self = shift;
    if (@_) { $self->{thumb_width} = shift }
    return $self->{thumb_width};
}

sub thread_spacer {
    my $self = shift;
    if (@_) { $self->{thread_spacer} = shift }
    return $self->{thread_spacer};
}

sub allow_attach {
    my $self = shift;
    if (@_) { $self->{allow_attach} = shift }
    return $self->{allow_attach};
}

sub allow_recom {
    my $self = shift;
    if (@_) { $self->{allow_recom} = shift }
    return $self->{allow_recom};
}

sub allow_scrap {
    my $self = shift;
    if (@_) { $self->{allow_scrap} = shift }
    return $self->{allow_scrap};
}

sub escaped_tags {
    my $self = shift;
    if (@_) { $self->{escaped_tags} = shift }
    return $self->{escaped_tags};
}

sub escaped_comment_tags {
    my $self = shift;
    if (@_) { $self->{escaped_comment_tags} = shift }
    return $self->{escaped_comment_tags}
}

sub is_imgboard {
    my $self = shift;
    if (@_) { $self->{is_imgboard} = shift }
    return $self->{is_imgboard};
}

sub is_anonboard {
    my $self = shift;
    if (@_) { $self->{is_anonboard} = shift }
    return $self->{is_anonboard};
}

sub created {
    my $self = shift;
    if (@_) { $self->{created} = shift }
    return $self->{created};
}

sub articles {
    my $self = shift;
    if (@_) { $self->{articles} = shift }
    return $self->{articles};
}

sub images {
    my $self = shift;
    if (@_) { $self->{images} = shift }
    return $self->{images};
}

sub max_article_no {
    my $self = shift;
    if (@_) { $self->{max_article_no} = shift }
    return $self->{max_article_no};
}

sub max_comment_no {
    my $self = shift;
    if (@_) { $self->{max_comment_no} = shift }
    return $self->{max_comment_no};
}

sub tot_page {
    my $self = shift;
    if (@_) { $self->{tot_page} = shift }
    return $self->{tot_page};
}

sub img {
    my $self = shift;
    if (@_) { $self->{img} = shift }
    return $self->{img};
}

sub page {
    my $self = shift;
    if (@_) { $self->{page} = shift }
    return $self->{page};
}

sub g_read {
    my $self = shift;
    if (@_) { $self->{g_read} = shift }
    return $self->{g_read};
}

sub m_read {
    my $self = shift;
    if (@_) { $self->{m_read} = shift }
    return $self->{m_read};
}

sub a_read {
    my $self = shift;
    if (@_) { $self->{a_read} = shift }
    return $self->{a_read};
}

sub g_write {
    my $self = shift;
    if (@_) { $self->{g_write} = shift }
    return $self->{g_write};
}

sub m_write {
    my $self = shift;
    if (@_) { $self->{m_write} = shift }
    return $self->{m_write};
}

sub a_write {
    my $self = shift;
    if (@_) { $self->{a_write} = shift }
    return $self->{a_write};
}

sub g_comment {
    my $self = shift;
    if (@_) { $self->{g_comment} = shift }
    return $self->{g_comment};
}

sub m_comment {
    my $self = shift;
    if (@_) { $self->{m_comment} = shift }
    return $self->{m_comment};
}

sub a_comment {
    my $self = shift;
    if (@_) { $self->{a_comment} = shift }
    return $self->{a_comment};
}

sub save_instance { 
    my ($self, %arg) = @_;

    my $sql = qq(update $TBL{board}
                 set title=?, 
                     keyword=?, 
                     uid=?,
                     id=?,
                     name=?,
                     seq=?, 
                     gid=?, 
                     article_per_page=?,
                     page_per_page=?,
                     attach_limit=?,
                     image_width=?,
                     thumb_width=?,
                     allow_attach=?,
                     allow_recom=?,
                     allow_scrap=?,
                     skin=?,
                     is_imgboard=?,
                     is_anonboard=?,
                     g_read=?,
                     m_read=?,
                     a_read=?,
                     g_write=?,
                     m_write=?,
                     a_write=?,
                     g_comment=?,
                     m_comment=?,
                     a_comment=?,
                     expire_days=?
                 where board_id=?
                );
    my $rv = $DBH->do($sql, undef, $self->title,
                                   $self->keyword,
                                   $self->uid,
                                   $self->id,
                                   $self->name,
                                   $self->seq,
                                   $self->gid,
                                   $self->article_per_page,
                                   $self->page_per_page,
                                   $self->attach_limit,
                                   $self->image_width,
                                   $self->thumb_width,
                                   $self->allow_attach,
                                   $self->allow_recom,
                                   $self->allow_scrap,
                                   $self->skin,
                                   $self->is_imgboard,
                                   $self->is_anonboard,
                                   $self->g_read,
                                   $self->m_read,
                                   $self->a_read,
                                   $self->g_write,
                                   $self->m_write,
                                   $self->a_write,
                                   $self->g_comment,
                                   $self->m_comment,
                                   $self->a_comment,
                                   $self->expire_days,
                                   $self->board_id);
    return $rv;
}


################################################################################
# Board

sub add_board { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-gid} &&
                   exists $arg{-keyword} &&
                   exists $arg{-title} &&
                   exists $arg{-skin} &&
                   exists $arg{-uid} &&
                   exists $arg{-id} &&
                   exists $arg{-name}); 

    my $sql = qq(INSERT INTO $TBL{board} 
                 (gid, keyword, title, skin, uid, id, name, created) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, NOW()));
    my $rv = $DBH->do($sql, undef, $arg{-gid}, 
                                   $arg{-keyword},
                                   $arg{-title},
                                   $arg{-skin},
                                   $arg{-uid},
                                   $arg{-id},
                                   $arg{-name});
    return $rv;
}


sub get_board_id { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-keyword});

    my $sql = qq(SELECT * FROM $TBL{board} WHERE keyword=?);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-keyword});
    return $rv;
}

sub get_board { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id});

    my $sql = qq(SELECT * FROM $TBL{board} WHERE board_id=?);
    my $rv = $DBH->selectall_hashref($sql, undef, $arg{-board_id});
    return $rv;
}

sub get_boardset {
    my ($self, %arg) = @_;
    return unless (exists $arg{-gid});

    my $sort = $arg{-sort} || 'seq';
    my $sql = qq(SELECT a.board_id, a.title, a.id, a.name, a.is_imgboard, 
                        a.is_anonboard, datediff(now(), b.created) as days,
                        a.seq
                 FROM $TBL{board} as a LEFT JOIN $TBL{head} as b
                 ON a.board_id=b.board_id AND a.max_article_no=b.article_no
                 WHERE a.gid=?);
    my $rv = $DBH->selectall_hashref($sql, 'board_id', undef, $arg{-gid});

    # added to support older MySQL (< 4.1)
    unless ($rv) {
        $sql = qq(SELECT a.board_id, a.title, a.id, a.name, a.is_imgboard, 
                         a.is_anonboard, '1' as nodays, 
                         a.seq
                  FROM $TBL{board} as a LEFT JOIN $TBL{head} as b
                  ON a.board_id=b.board_id AND a.max_article_no=b.article_no
                  WHERE a.gid=?);
        $rv = $DBH->selectall_hashref($sql, 'board_id', undef, $arg{-gid});
    }
    my @rv;
    if ($sort eq 'title') {
        @rv = sort { $a->{title} cmp $b->{title} ||
                     $a->{seq} <=> $b->{seq} ||
                     $a->{board_id} <=> $b->{board_id} }
              map { $$rv{$_} }
              keys %$rv;
    } else {
        @rv = sort { $a->{$sort} <=> $b->{$sort} ||
                     $a->{seq} <=> $b->{seq} || 
                     $a->{board_id} <=> $b->{board_id} }
              map { $$rv{$_}->{days} = -1 unless (defined $$rv{$_}->{days});
                    $$rv{$_} }
              keys %$rv;
    }
    return \@rv;
}

sub exists_keyword { 
    my ($self, $keyword) = @_;
    return unless ($keyword);

    my $sql = qq(SELECT keyword FROM $TBL{board} where keyword=?);
    my $rv = $DBH->selectrow_array($sql, undef, $keyword);
    if ($rv && $rv eq $keyword) {
        return 1;
    } else {
        return 0;
    }
}

################################################################################
# Article
# NOTE:
# 1. Include 'page' in the SQL statement to avoid 'global-vars' option in 
#    HTML::Template.
# 2. Array of Hash is the best data type for HTML::Template

sub get_articlelist {
    my ($self, %arg) = @_;

    my $bid = $self->board_id || 0;
    my $tot_page = $self->tot_page || 1;
    my $page = $self->page || $tot_page || 1;
    my $article_per_page = $self->article_per_page || 16;
    my $start = &get_start($page, $tot_page, $article_per_page);
    my $img = $self->img || 0;
    my $is_anonboard = $self->is_anonboard || 0;
    my $allow_recom = $self->allow_recom || 0;
    my $allow_scrap = $self->allow_scrap || 0;
    my $allow_recom_user_list = $self->cfg->AllowRecomUserList || 0;

    my $keyword = $arg{-keyword} || '';
    my $field = $arg{-field} || '';
    my $search_select = '';
    my $search_where = '';
    if ($keyword && $field && $field =~ /title|id|name/) {
        $keyword = &sql_search_pattern_escape($keyword); 
        $search_select = qq(, '$keyword' as keyword, '$field' as field);
        $search_where = qq(&& $field like '\%$keyword\%');
    }
    $search_where = '' if ($self->is_anonboard && $field ne 'title');

    my $sql = qq(SELECT board_id, article_no, parent_no, article_id, thread_no, 
                        REPLACE(title, '<', '&lt;') as title, uid, id, name, 
                        IF( created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(created, '%m/%d'),
                          DATE_FORMAT(created, '%y/%m/%d') ) as created,
                        DATE_FORMAT(created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        count, recom, 
                        scrap, comments, has_attach, has_poll, 
                        $page as page, $img as img 
                        $search_select,
                        $is_anonboard as is_anonboard,
                        $allow_recom as allow_recom, 
                        $allow_scrap as allow_scrap,
                        $allow_recom_user_list as allow_recom_user_list
                 FROM $TBL{head} 
                 WHERE board_id=$bid $search_where
                 ORDER BY article_no DESC limit $start, $article_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'article_no');
    my $formated = &format_article_list($rv);

    undef $rv;

    return $formated; 
}

sub get_notice_articlelist {
    my ($self, %arg) = @_;

    my $bid = $self->board_id || 0;
    my $tot_page = $self->tot_page || 1;
    my $page = $self->page || $tot_page;
    my $img = $self->img || 0;
    my $allow_recom = $self->allow_recom || 0;
    my $allow_scrap = $self->allow_scrap || 0;
    my $allow_recom_user_list = $self->cfg->AllowRecomUserList || 0;

    my $sql = qq(SELECT a.board_id, a.article_no, a.parent_no, a.article_id, 
                        a.thread_no, REPLACE(a.title, '<', '&lt;') as title, 
                        a.id, a.name,
                        IF( a.created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(a.created, '%m/%d'),
                          DATE_FORMAT(a.created, '%y/%m/%d') ) as created,
                        DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        a.count, a.recom, a.scrap, a.comments, a.has_attach, 
                        a.has_poll, $page as page, 
                        $img as img, $allow_recom as allow_recom,
                        $allow_scrap as allow_scrap,
                        $allow_recom_user_list as allow_recom_user_list
                 FROM $TBL{head} as a, $TBL{notice} as b 
                 WHERE a.board_id=b.board_id && 
                       a.article_id=b.article_id && 
                       a.board_id=? 
                 ORDER BY article_no DESC);
    my $rv = $DBH->selectall_hashref($sql, 'article_no', undef, $bid);
    my @rv = sort { $b->{article_id} <=> $a->{article_id} } 
             map { $$rv{$_} }
             keys %$rv;
    return \@rv; 
}

sub get_img_articlelist {
    my ($self, %arg) = @_;

    my $bid = $self->board_id || 0;
    my $tot_page = $self->tot_page || 1;
    my $page = $self->page || $tot_page;
    my $article_per_page = $self->{article_per_page} || 16;
    my $start = &get_start($page, $tot_page, $article_per_page);
    my $is_anonboard = $self->is_anonboard || 0;
    my $sql = qq(SELECT a.board_id, a.article_no, a.article_id,
                        REPLACE(a.title, '<', '&lt;') as title, a.uid, a.id, 
                        a.name, a.count, a.recom, a.scrap, a.comments, 
                        a.has_attach, a.has_poll,
                        b.attach_id, $is_anonboard as is_anonboard, 
                        $page as page 
                 FROM $TBL{head} as a, $TBL{attach} as b 
                 WHERE a.board_id=? && a.article_id=b.article_id && b.is_img='y'
                 ORDER BY a.article_no DESC, b.attach_id DESC 
                 LIMIT $start, $article_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'attach_id', undef, $bid);
    my @rv = sort { $b->{attach_id} <=> $a->{attach_id} } 
             map { $$rv{$_} }
             keys %$rv;

    return \@rv; 
}

sub get_recom_articlelist {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $tot_page = $self->{tot_page} || 1;
    my $page = $self->page || $tot_page || 1; 
    my $article_per_page = $self->{article_per_page} || 16;
    my $start = &get_start($page, $tot_page, $article_per_page);
    my $sql = qq(SELECT a.board_id, a.article_id, 
                        REPLACE(a.title, '<', '&lt;') as title, a.uid, 
                        a.id, a.name,
                        IF( a.created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(a.created, '%m/%d'),
                          DATE_FORMAT(a.created, '%y/%m/%d') ) as created,
                        DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        a.count, a.recom, a.scrap, a.comments, a.has_attach,
                        a.has_poll, $page as page,
                        c.title as board_title
                 FROM $TBL{head} as a, $TBL{recom} as b, $TBL{board} as c
                 WHERE a.article_id=b.article_id && a.board_id=c.board_id && 
                       b.uid=?
                 ORDER BY a.article_id DESC limit $start, $article_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'article_id', undef, $arg{-uid});
    my @rv = map { $rv->{$_} } sort {$b <=> $a} keys %$rv;
    return \@rv; 
}

sub get_scrap_articlelist {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $tot_page = $self->{tot_page} || 1;
    my $page = $self->page || $tot_page || 1; 
    my $article_per_page = $self->{article_per_page} || 16;
    my $start = &get_start($page, $tot_page, $article_per_page);
    my $sql = qq(SELECT a.board_id, a.article_id, 
                        REPLACE(a.title, '<', '&lt;') as title, a.uid, 
                        a.id, a.name,
                        IF( a.created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(a.created, '%m/%d'),
                          DATE_FORMAT(a.created, '%y/%m/%d') ) as created,
                        DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        a.count, a.recom, a.scrap, a.comments, a.has_attach, 
                        a.has_poll, $page as page,
                        c.title as board_title, b.scrapped as scrapped 
                 FROM $TBL{head} as a, $TBL{scrap} as b, $TBL{board} as c
                 WHERE a.article_id=b.article_id && a.board_id=c.board_id && 
                       b.uid=?
                 ORDER BY b.scrapped DESC, a.article_id DESC limit $start, $article_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'article_id', undef, $arg{-uid});
	my @rv = sort { ($b->{scrapped} || 0) cmp ($a->{scrapped} || 0) ||
					$b->{article_id} cmp $a->{article_id} }
			 map { $$rv{$_} }
			 keys %$rv;
    return \@rv; 
    
}

sub get_scrap_articlelist_by_board {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});
	return unless (exists $arg{-bid});

    my $tot_page = $self->{tot_page} || 1;
    my $page = $self->page || $tot_page || 1; 
    my $article_per_page = $self->{article_per_page} || 16;
    my $start = &get_start($page, $tot_page, $article_per_page);
    my $sql = qq(SELECT a.board_id, a.article_id, 
                        REPLACE(a.title, '<', '&lt;') as title, a.uid, 
                        a.id, a.name,
                        IF( a.created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(a.created, '%m/%d'),
                          DATE_FORMAT(a.created, '%y/%m/%d') ) as created,
                        DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        a.count, a.recom, a.scrap, a.comments, a.has_attach, 
                        a.has_poll, $page as page,
                        c.title as board_title, b.scrapped as scrapped
                 FROM $TBL{head} as a, $TBL{scrap} as b, $TBL{board} as c
                 WHERE a.article_id=b.article_id && a.board_id=c.board_id && 
                       b.uid=? && a.board_id=?
                 ORDER BY b.scrapped DESC, a.article_id DESC limit $start, $article_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'article_id', undef, $arg{-uid}, $arg{-bid});
	my @rv = sort { ($b->{scrapped} || 0) cmp ($a->{scrapped} || 0) ||
					$b->{article_id} cmp $a->{article_id} }
			 map { $$rv{$_} }
			 keys %$rv;
    return \@rv; 
}

sub get_article {
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $bid = $self->board_id || $arg{-board_id} || 0;
    my $aid = $arg{-article_id} || 0;
    my $page = $self->page || $self->tot_page || 1; 
    my $img = $self->img || 0;
    my $is_anonboard = $self->is_anonboard || 0;
    my $allow_recom = $self->allow_recom || 0;
    my $allow_scrap = $self->allow_scrap || 0;
    my $allow_recom_user_list = $self->cfg->AllowRecomUserList || 0;
    my $session_key = $self->session_key || 0;
    my $expired = $self->expire_days || 36500; # 100 years
    
    my $sql = qq(SELECT a.board_id, a.article_no, a.article_id, a.thread_no, 
                        a.title, a.uid, a.id, a.name,
                        IF( a.created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(a.created, '%m/%d %H:%i'),
                          DATE_FORMAT(a.created, '%y/%m/%d %H:%i') ) as created,
                        DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        a.count, a.recom, a.scrap, a.has_attach, a.has_poll, a.comments,
                        a.created + INTERVAL $expired DAY < now() as expired,
                        b.body, $page as page, $img as img,
                        $is_anonboard as is_anonboard,
                        '$session_key' as session_key,
                        $allow_recom as allow_recom,
                        $allow_scrap as allow_scrap,
                        $allow_recom_user_list as allow_recom_user_list
                 FROM $TBL{head} as a, $TBL{body} as b 
                 WHERE a.article_id=b.article_id && a.board_id=? && 
                       a.article_id=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $bid, $aid);

    return $rv;
}

sub add_article_read_count {
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $sql = qq(UPDATE $TBL{head} set count=count+1 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $arg{-article_id});
    return $rv;
}

sub get_thread { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-thread_no});

    my $thread_no = $arg{-thread_no} || 0;
    my $uid = $arg{-uid} || 0;
    my $bid = $self->board_id || 0;
    my $page = $self->page || $self->tot_page || 1;
    my $img = $self->img || 0;
    my $is_anonboard = $self->is_anonboard || 0;
    my $allow_recom = $self->allow_recom || 0;
    my $allow_scrap = $self->allow_scrap || 0;
    my $allow_recom_user_list = $self->cfg->AllowRecomUserList || 0;
    my $session_key = $self->session_key || 0;
    my $expired = $self->expire_days || 36500; # 100 years
    
    my $sql = qq(UPDATE $TBL{head} SET count=count+1 
                 WHERE board_id=? && thread_no=? && uid != ?);
    my $rv = $DBH->do($sql, undef, $bid, $thread_no, $uid);
    $sql = qq(SELECT a.board_id, a.article_no, a.article_id, a.thread_no, 
                     a.title, a.uid, a.id, a.name,
                     IF( a.created + INTERVAL 180 DAY > now(), 
                       DATE_FORMAT(a.created, '%m/%d %H:%i'),
                       DATE_FORMAT(a.created, '%y/%m/%d %H:%i') ) as created,
                     DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                     a.count, a.recom, a.scrap, a.has_attach, a.has_poll, a.comments,
                     b.body, $page as page, $img as img, 
                     a.created + INTERVAL $expired DAY < now() as expired,
                     $is_anonboard as is_anonboard,
                     '$session_key' as session_key,
                     $allow_recom as allow_recom, $allow_scrap as allow_scrap,
                     $allow_recom_user_list as allow_recom_user_list
              FROM $TBL{head} as a, $TBL{body} as b 
              WHERE a.board_id=? && a.thread_no=? && a.article_id=b.article_id);
    $rv = $DBH->selectall_hashref($sql, 'article_no', undef, $bid,
                                                             $thread_no);
    my @rv = map { ${$rv}{$_} } sort { $a <=> $b } keys %$rv;
    return \@rv;
}

sub get_new_articles { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_no});

    my $ano = $arg{-article_no} || 0;
    my $bid = $self->board_id || 0;
    my $page = $self->tot_page || 1;
    my $img = $self->img || 0;
    my $is_anonboard = $self->is_anonboard || 0;
    my $allow_recom = $self->allow_recom || 0;
    my $allow_scrap = $self->allow_scrap || 0;
    my $allow_recom_user_list = $self->cfg->AllowRecomUserList || 0;
    my $session_key = $self->session_key || 0;
    my $expired = $self->expire_days || 36500; # 100 years
    
    my $sql2 = qq(SELECT a.board_id, a.article_no, a.article_id, a.thread_no, 
                     a.title, a.uid, a.id, a.name,
                     IF( a.created + INTERVAL 180 DAY > now(), 
                       DATE_FORMAT(a.created, '%m/%d %H:%i'),
                       DATE_FORMAT(a.created, '%y/%m/%d %H:%i') ) as created,
                     DATE_FORMAT(a.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                     a.count, a.recom, 
                     a.scrap, a.has_attach, a.has_poll, a.comments, 
                     a.created + INTERVAL $expired DAY < now() as expired,
                     b.body, $page as page, $img as img,
                     $is_anonboard as is_anonboard,
                     '$session_key' as session_key,
                     $allow_recom as allow_recom, $allow_scrap as allow_scrap,
                     $allow_recom_user_list as allow_recom_user_list
              FROM $TBL{head} as a, $TBL{body} as b 
              WHERE a.board_id=? && a.article_no > ? && 
                    a.article_id=b.article_id );
    $sql2 .= "limit $arg{-max_article_count}" if $arg{-max_article_count};

    my $rv = $DBH->selectall_hashref($sql2, 'article_no', undef, $bid, $ano);
    my @rv = map { ${$rv}{$_} } sort { $a <=> $b } keys %$rv;

    my $sql1 = qq(UPDATE $TBL{head} SET count=count+1 
                  WHERE board_id=? && article_no>? and article_no<=?);
    my $last_article = $rv[-1];
    $rv = $DBH->do($sql1, undef, $bid, $ano, $last_article->{article_no});
    return \@rv;
}

sub get_pagenav { 
    my ($self, %arg) = @_;

    my $bid = $self->board_id || 0;
    my $tot_article = $self->articles || 0;
    my $article_per_page = $self->article_per_page || 16;
    my $page_per_page = $self->page_per_page || 10;
    my $tot_page = $self->tot_page || 1;
    my $page = $self->page || $tot_page || 1;
    $page = $tot_page < $page ? $tot_page : $page;
    my $img = $self->img || 0;
    my $keyword = $arg{-keyword} || '';
    my $field = $arg{-field} || '';

    my $start = $page % $page_per_page ? 
        ( int($page / $page_per_page) + 1 ) * $page_per_page :
        int($page / $page_per_page) * $page_per_page; 
    $start = $start > $tot_page ? $tot_page : $start;
    my $end = $start - $page_per_page + 1;
    $end = 1 if ($end < 1);
    my @pages;
    for (my $i = $start; $i >= $end; $i--) {
        my $current = $page == $i ? 1 : 0;
        push @pages, { page=>$i, 
                       board_id=>$bid, 
                       current=>$current, 
                       img=>$img,
                       keyword=>$keyword,
                       field=>$field };
    }
    my %rv;
    $rv{pages} = \@pages;
    $rv{page} = $page;
    $rv{next_page} = $end - 1 if ($end - 1 > 0);
    $rv{prev_page} = $start + 1 if ($start + 1 <= $tot_page);
    $rv{first_page} = 1 if ($page > $page_per_page);
    $rv{last_page} = $tot_page if ($page <= $tot_page - $page_per_page + 1);

    return \%rv;
}

sub add_article { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && 
                   exists $arg{-title} &&
                   exists $arg{-body} &&
                   exists $arg{-uid} &&
                   exists $arg{-id} &&
                   exists $arg{-name}
                  );

    # 1. lock table: $TBL{head}, $TBL{body}
    # 2. get article_no
    # 3. get parent_no if no parent_no
    # 4. get thread_no if no thread_no
    # 5. insert into $TBL{head}
    # 6. select last_insert_id
    # 7. insert into $TBL{body}
    # 8. unlock table

    my $sql = qq(LOCK TABLES $TBL{head} WRITE, $TBL{body} WRITE, 
                             $TBL{board} WRITE, $TBL{bookmark} WRITE);
    my $rv = $DBH->do($sql);
    my $article_no = $self->{max_article_no} + 1; 
    my $parent_no = $arg{-parent_no} || $article_no;
    my $thread_no = $arg{-thread_no} || &get_next_thread_no($arg{-board_id});
    
    $sql = qq(INSERT INTO $TBL{head} (article_no, parent_no, thread_no, board_id, title, uid, id, name, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW()));
    $rv = $DBH->do($sql, undef, $article_no,
                                $parent_no,
                                $thread_no,
                                $arg{-board_id},
                                $arg{-title},
                                $arg{-uid},
                                $arg{-id},
                                $arg{-name});
    $sql = qq(SELECT LAST_INSERT_ID());
    my $aid = $DBH->selectrow_array($sql);
    $sql = qq(INSERT INTO $TBL{body} (article_id, board_id, body) 
              VALUES (LAST_INSERT_ID(), ?, ?));
    $rv = $DBH->do($sql, undef, $arg{-board_id}, $arg{-body});
    &add_article_count($arg{-board_id});
    my $bm = $self->get_bookmark(-board_id=>$arg{-board_id}, 
                                 -uid=>$arg{-uid});
    if ($bm->{article_no} && $article_no == $bm->{article_no} + 1) {
        $self->{max_article_no} = $article_no;
        $self->set_article_bookmark(-board_id=>$arg{-board_id}, 
                                    -uid=>$arg{-uid});
    }

    $sql = qq(UNLOCK TABLES);
    $rv = $DBH->do($sql);
    
    return $aid;
}

sub edit_article { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && 
                   exists $arg{-title} &&
                   exists $arg{-body});

    my $sql = qq(UPDATE $TBL{head} SET title=? WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $arg{-title}, $arg{-article_id});
    $sql = qq(UPDATE $TBL{body} SET body=? WHERE article_id=?);
    $rv = $DBH->do($sql, undef, $arg{-body}, $arg{-article_id});
    return $rv;
}

sub del_article { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-article_id});

    # as for comments, only remove comments from the same user as the
    # article in question
    my $article_uid = $self->get_article_uid(-article_id=>$arg{-article_id});

    # $TBL{head}, $TBL{body}, $TBL{comment}, $TBL{attach}, ($TBL{notice})
    # update $TBL{board}: articles
    my $del = 0;
    foreach my $i ( qw( head body attach notice) ) {
        my $sql = qq(DELETE FROM $TBL{$i} WHERE article_id=?);
        my $rv = $DBH->do($sql, undef, $arg{-article_id});
        if ($rv == 1) {
            ++$del;
            $self->del_attachset(-article_id=>$arg{-article_id});
        }
    }

    my $sql = qq(UPDATE $TBL{head} SET recom=0 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $arg{-article_id});

    $sql = qq(UPDATE $TBL{head} SET title=? WHERE article_id=?);
    $rv = $DBH->do($sql, undef, "*** Deleted by author ***", $arg{-article_id});

    $sql = qq(UPDATE $TBL{body} SET body=? WHERE article_id=?);
    $rv = $DBH->do($sql, undef, "*** Deleted by author ***", $arg{-article_id});

    # Update the comments from the user of the article
    $sql = qq(UPDATE $TBL{comment} SET body=? WHERE uid=? && article_id=?);
    $rv = $DBH->do($sql, undef, "*** Deleted by author ***", $article_uid, $arg{-article_id});

    if ($rv == 1) {
        ++$del;
        # If comments are deleted, possibly references should be cleaned up as well.
        # In general, only need to SQL select ref_ids that no longer exists in comment
#        $sql = qq(DELETE FROM $TBL{commentref}
#                  WHERE NOT EXISTS (SELECT 1 FROM $TBL{comment} as b WHERE ref_id = b.comment_id)
#                );
#        $rv = $DBH->do($sql);
#
#        # also the actual comments that are dangling
#        $sql = qq(DELETE FROM $TBL{commentref}
#                  WHERE NOT EXISTS (SELECT 1 FROM $TBL{comment} as b WHERE $TBL{commentref}.comment_id = b.comment_id) );
#        $rv = $DBH->do($sql);
                    
    }

#    # Update the dangling comments that have the article_id
#    $sql = qq(UPDATE $TBL{comment} SET article_id=0 WHERE article_id=?);
#    $rv = $DBH->do($sql, undef, $arg{-article_id});

#    if ($del) {
#        &dec_article_count($arg{-board_id});
#        &update_max_article_no($arg{-board_id});
#        &update_max_comment_no($arg{-board_id});
#        &update_bookmark($arg{-board_id});
#    }
    return $del;
}


sub add_recommender { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && exists $arg{-uid});

    my $sql = qq(INSERT INTO $TBL{recom} (uid, article_id, rectime) VALUES (?, ?, NOW()) );
    my $rv = $DBH->do($sql, undef, $arg{-uid}, $arg{-article_id});

    &add_recom_count($arg{-article_id}) if ($rv and $self->{allow_recom} == 1);
    return $rv;
}

sub add_recom {
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && exists $arg{-uid});
    my $sql = qq(REPLACE INTO $TBL{recom} (uid, article_id, rectime) VALUES (?, ?, NOW()));
    my $rv = $DBH->do($sql, undef, $arg{-uid}, $arg{-article_id});
    return $rv;
}

sub get_scrap { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && exists $arg{-uid});

    my $sql = qq(SELECT uid, article_id FROM $TBL{scrap} 
                 WHERE uid=? && article_id=?);
    my @rv = $DBH->selectrow_array($sql, undef, $arg{-uid}, $arg{-article_id});
    return @rv;
}

sub add_scrap { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && exists $arg{-uid} && exists $arg{-last_comment_no});

    my $sql = qq(INSERT INTO $TBL{scrap} (uid, article_id, last_comment_no, scrapped) VALUES(?, ?, ?, NOW()) );
    my $rv = $DBH->do($sql, undef, $arg{-uid}, $arg{-article_id}, $arg{-last_comment_no});

    &add_scrap_count($arg{-article_id}) if ($rv and $self->{allow_scrap} == 1);
    return $rv;
}

sub delete_scrap {
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && exists $arg{-uid});

    my $sql = qq(DELETE FROM $TBL{scrap} WHERE uid=? AND article_id=? );
    my $rv = $DBH->do($sql, undef, $arg{-uid}, $arg{-article_id});
    
    &dec_scrap_count($arg{-article_id}) if ($rv and $self->{allow_scrap} == 1);

	return $rv;
}

sub get_recommender { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && exists $arg{-uid});

    my $sql = qq(SELECT uid, article_id FROM $TBL{recom} 
                 WHERE uid=? && article_id=?);
    my @rv = $DBH->selectrow_array($sql, undef, $arg{-uid}, $arg{-article_id});
    return @rv;
}

sub get_recom_user_list { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $sql = qq(SELECT a.uid, a.id, a.name, b.rectime 
                 FROM $TBL{passwd} as a, $TBL{recom} as b 
                 WHERE a.uid=b.uid && b.article_id=? ORDER BY b.rectime);
    my $rv = $DBH->selectall_hashref($sql, 'uid', undef, $arg{-article_id});
    my @rv = sort { $a->{rectime} cmp $b->{rectime} }
#    my @rv = sort { $a->{name} cmp $b->{name} ||
#                    $a->{id} cmp $b->{id} }
              map { $$rv{$_} }
             keys %$rv;

    return \@rv;
}

sub get_article_uid { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $sql = qq(SELECT uid FROM $TBL{head} WHERE article_id=?);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-article_id});
    return $rv;
}

sub format_article { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-body});

    my $article = $arg{-article};
    my $body = $arg{-body};
    my @body = split(/\r?\n/, $body);
    my ( $was_inside_html_tag, $is_inside_html_tag, $inside_span )  = (0, 0, 0);
    foreach ( @body ) {
        # be aware that wrap_long_line() adds '\n' at the end of each string.
        # '2' means html document from old board's attrib.
        # $_ = &wrap_long_line($_, 2); 
        chomp;

        $_ = &escape_tags($self, $_);
        $_ = &make_hyperlink($self, $_, $article);
        ($_, $was_inside_html_tag, $is_inside_html_tag, $inside_span)
            = &make_quote_coloring($_, $was_inside_html_tag, $is_inside_html_tag, $inside_span);
    }

    #$body = join("\n", @body);
    $body = join("<br />\n", @body);
    
    return $body;
}

sub format_anon_list { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-list});

    my $list = $arg{-list};
    my %alias;
    my $count = 1;
    foreach my $i (@$list) {
        my $uid = $$i{uid} || '';
        $alias{$uid} = $count++ unless ($alias{$uid});
        $$i{name} = $alias{$uid};
        delete $$i{id};
        if ($$i{comment}) {
            foreach my $j (@{$$i{comment}}) {
                my $uid = $$j{uid} || '';
                $alias{$uid} = $count++ unless ($alias{$uid});
                $$j{name} = $alias{$uid};
                delete $$i{id};
            }
        }
    }
    return $list;
}

sub x { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id});

    my $sql = qq();
    my $rv = $DBH->($sql, undef, $arg{-board_id});
    return $rv;
}

################################################################################
# Comment

sub add_comment {
    my ($self, %arg) = @_;
    return undef unless (exists $arg{-article_id} &&
                         exists $arg{-board_id} &&
                         exists $arg{-body} &&
                         exists $arg{-uid} &&
                         exists $arg{-id} &&
                         exists $arg{-name}
                        );

    my $comment_no = $self->{max_comment_no} + 1;
    my $sql = qq(INSERT INTO $TBL{comment} 
                 (comment_no, board_id, article_id, body, uid, id, name, created)
                 VALUES (?, ?, ?, ?, ?, ?, ?, now() ) );
    my $rv = $DBH->do($sql, undef, $comment_no,
                                   $arg{-board_id},
                                   $arg{-article_id},
                                   $arg{-body},
                                   $arg{-uid},
                                   $arg{-id},
                                   $arg{-name},
                     );

    # parse the body to find out potential comment_no to insert
    # this needs to be concurrent with the previous sql
    # always contains self

    $sql = qq(INSERT INTO $TBL{commentref}
              (board_id, article_id, comment_id, comment_no, ref_id, ref_no)
              SELECT 
                board_id, 
                article_id, 
                comment_id, 
                comment_no, 
                comment_id as ref_id, 
                comment_no as ref_no
              FROM $TBL{comment}
              WHERE board_id=? && comment_no=? );
    my $rv2 = $DBH->do($sql, undef, $arg{-board_id}, $comment_no);

    # split all and iterate
    # my @reference_comment_no = $arg{-body} =~ m/#([0-9]+)/g;
    my %reference_comment_no;
    map { $reference_comment_no{$_} = 1 if ($_ > 0); } ($arg{-body} =~ m/#([0-9]+)($|\s)/g);
    foreach my $cn (keys %reference_comment_no) {
        $sql = qq(INSERT INTO $TBL{commentref}
                  (board_id, article_id, comment_id, comment_no, ref_id, ref_no)
                  SELECT
                     a.board_id,
                     a.article_id,
                     a.comment_id,
                     a.comment_no,
                     b.comment_id as ref_id,
                     b.comment_no as ref_no
                  FROM $TBL{comment} a, $TBL{comment} b
                  WHERE a.board_id=? && b.board_id=? && a.comment_no=? && b.comment_no=? && b.article_id=a.article_id limit 1);

         my $rv2 = $DBH->do($sql, undef, 
                                 $arg{-board_id},
                                 $arg{-board_id},
                                 $comment_no,
                                 $cn
                        );
    }

    &add_comment_count($arg{-article_id}, $arg{-board_id}) if $rv;
    my $bm = $self->get_bookmark(-board_id=>$arg{-board_id}, 
                                 -uid=>$arg{-uid});
    if ($bm->{comment_no} && $comment_no == $bm->{comment_no} + 1) {
        $self->{max_comment_no} = $comment_no;
        $self->set_comment_bookmark(-board_id=>$arg{-board_id}, 
                                    -uid=>$arg{-uid});
    }

    return $comment_no;
}

sub edit_comment {
    # deprecated. If this is to be used, need to consider ref comments
    my ($self, %arg) = @_;
    return undef unless (exists $arg{-comment_id} && 
                         exists $arg{-body} &&
                         exists $arg{-uid});

    my $sql = qq(UPDATE $TBL{comment} SET body=?, created=now() 
                 WHERE comment_id=? && uid=?);
    my $rv = $DBH->do($sql, undef, $arg{-body}, $arg{-comment_id}, $arg{-uid});
    return $rv;
}

sub get_comment {
    my ($self, %arg) = @_;
    return undef unless (exists $arg{-comment_id});
    my $expired = $self->expire_days || 36500; # 100 years
    
    my $sql = qq(SELECT comment_id, board_id, article_id, body, uid, id, name, 
                        IF( created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(created, '%m/%d %H:%i'),
                          DATE_FORMAT(created, '%y/%m/%d %H:%i') ) as created,
                        DATE_FORMAT(created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        created + INTERVAL $expired DAY < now() as comment_expired
                 FROM $TBL{comment} WHERE comment_id=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $arg{-comment_id});
    if ($rv) {
        $rv->{body} = $self->escape_comment_tags($rv->{body});
        $rv->{body} = $self->make_hyperlink($rv->{body}, $rv);
    }
    return $rv;
}

sub get_commentset {
    my ($self, %arg) = @_;
    return undef unless (exists $arg{-article_id} && exists $arg{-uid});
    
    my $bid = $arg{-board_id} || $self->board_id || 0;
    my $aid = $arg{-article_id} || 0;
    my $uid = $arg{-uid} || -1;
    my $page = $self->page || $self->tot_page || 1;
    my $is_anonboard = $self->is_anonboard || 0;
    my $expired = $self->expire_days || 36500; # 100 years

    my $sql = qq(SELECT comment_id, board_id, article_id, body, uid, id, name, 
                        IF( created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(created, '%m/%d %H:%i'),
                          DATE_FORMAT(created, '%y/%m/%d %H:%i') ) as created,
                        DATE_FORMAT(created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        created + INTERVAL $expired DAY < now() as comment_expired,
                        $page as page, comment_no,
                        $is_anonboard as is_anonboard
                 FROM $TBL{comment} WHERE board_id=? && article_id=? 
                 ORDER BY comment_id);
    my $rv = $DBH->selectall_hashref($sql, 'comment_id', undef, $bid,
                                                                $aid);
    my @rv = map { $$rv{$_}->{is_owner} = $$rv{$_}->{uid} == $uid ? 1 : 0;
                   ${$rv}{$_} }
             sort { $a <=> $b } keys %$rv;
    @rv = @{ $self->format_commentset(\@rv) };
    return \@rv;
}

sub get_new_comments {
    my ($self, %arg) = @_;
    return undef unless (exists $arg{-comment_no});
    
    my $bid = $self->board_id || 0;
    my $page = $self->page || $self->tot_page || 1;
    my $last_article_no = $arg{-last_article_no} || $self->{max_article_no};
    my $img = $self->img || 0;
    my $is_anonboard = $self->is_anonboard || 0;
    my $expired = $self->expire_days || 36500; # 100 years

    # Note that this SQL is super slow compared to the original one. Need optimization
    # probably because of the two join operations?
    my $sql = qq(SELECT c.comment_id, c.board_id, c.article_id, c.body, c.uid, 
                        c.id, c.name,
                        IF( c.created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(c.created, '%m/%d %H:%i'),
                          DATE_FORMAT(c.created, '%y/%m/%d %H:%i') ) as created,
                        DATE_FORMAT(c.created, '%Y/%m/%d (%a) %H:%i:%s') as created_str,
                        c.created + INTERVAL $expired DAY < now() as comment_expired,
                        h.article_id, h.article_no, h.title,
                        h.id as artcl_id, 
                        h.name as artcl_name,
                        IF( h.created + INTERVAL 180 DAY > now(), 
                          DATE_FORMAT(h.created, '%m/%d %H:%i'),
                          DATE_FORMAT(h.created, '%y/%m/%d %H:%i') ) as artcl_created,
                        $page as page, 
                        c.comment_no as comment_no, $img as img,
                        $is_anonboard as is_anonboard
                 FROM $TBL{commentref} as r
                 INNER JOIN $TBL{comment} as c ON r.ref_id = c.comment_id
                 INNER JOIN $TBL{head} as h ON r.board_id=h.board_id && r.article_id=h.article_id
                 WHERE r.board_id=? && r.comment_no > ? && h.article_no <= ?
                 ORDER BY c.comment_id);
    my $rv = $DBH->selectall_hashref($sql, 'comment_id', undef, $bid,
                                                                $arg{-comment_no}, 
                                                                $last_article_no);
    my @rv = map { ${$rv}{$_} } 
             sort { ${$rv}{$a}{article_no} <=> ${$rv}{$b}{article_no} || 
                    $a <=> $b }
             keys %$rv;
    @rv = @{ $self->format_commentset(\@rv) };
    return \@rv;
}

sub del_comment {
    my ($self, %arg) = @_;
    return undef unless (exists $arg{-comment_id} && exists $arg{-article_id});

    my $sql = qq(UPDATE $TBL{comment} SET body= ?  WHERE comment_id = ?);
    my $rv = $DBH->do($sql, undef, "** Deleted by author **", $arg{-comment_id}); 
#    if ($rv) {
#        &dec_comment_count($arg{-article_id});
#        &update_max_comment_no( $arg{-board_id} );
#        &update_bookmark( $arg{-board_id} );
#
##        # remove also for the commentref
##        $sql = qq(DELETE FROM $TBL{commentref} WHERE comment_id = ?);
##        my $rv2 = $DBH->do($sql, undef, $arg{-comment_id});
##
##        $sql = qq(DELETE FROM $TBL{commentref} WHERE ref_id = ?);
##        $rv2 = $DBH->do($sql, undef, $arg{-comment_id});
#    }
    return $rv;
}

sub del_commentset {
    my ($self, %arg) = @_;
    return undef unless (exists $arg{-article_id} && exists $arg{-board_id});

    # this is deprecated because deletes only user id generated comments
    # so be careful in using this!

    my $sql = qq(DELETE FROM $TBL{comment} WHERE board_id=? && article_id=?);
    my $rv = $DBH->do($sql, undef, $arg{-board_id}, $arg{-article_id});

    if ($rv) {
        &update_max_comment_no( $arg{-board_id} );
        &update_bookmark( $arg{-board_id} );

        # if the entire thing is removed, also removed commentref
        $sql = qq(DELETE FROM $TBL{commentref} WHERE board_id=? && article_id?);
        my $rv2 = $DBH->do($sql, undef, $arg{-board_id}, $arg{-article_id});

        # Clean up commentref as well
        # Now need to remove all commentref that does not have corresponding
        # comment_id in comment table as well.
        # This is innucous if the SELECT operation is done well, so TODO
    }
    return $rv;
}

sub format_commentset {
    my ($self, $comments) = @_;

    foreach my $c (@$comments) {
        next unless (exists $c->{body});
        $c->{body} = &escape_comment_tags($self, $c->{body});
        $c->{body} = &make_hyperlink($self, $c->{body}, $c);
    }
    return $comments;
}

sub get_last_comment_no {
    # for scrapbook extension
    # by wwolf

    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});
	return unless (exists $arg{-article_id});

	my $sql = qq(SELECT MAX(comment_no) FROM $TBL{comment} WHERE article_id=?);
    
	my $rv = $DBH->selectrow_array($sql, undef, $arg{-article_id});
    return 0 || $rv;
}

################################################################################
# Bookmark

sub get_bookmark { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $sql = qq(SELECT article_no, comment_no FROM $TBL{bookmark}
                 WHERE board_id=? && uid=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $arg{-board_id}, $arg{-uid});
    return $rv;
}

sub get_bookmarkset { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(SELECT a.board_id, a.title, a.id, a.name, a.is_imgboard,
                        GREATEST(CAST(a.max_article_no as signed) - CAST(b.article_no as signed), 0) as new_articles,
                        GREATEST(CAST(a.max_comment_no as signed) - CAST(b.comment_no as signed), 0) as new_comments,
                        b.article_no,
                        b.comment_no,
                        b.seq
                 FROM $TBL{board} as a, $TBL{bookmark} as b
                 WHERE b.uid=? && b.board_id=a.board_id GROUP BY b.board_id); 
    my $rv = $DBH->selectall_hashref($sql, 'board_id', undef, $arg{-uid});
    my @rv = map { $$rv{$_}; } 
             sort { $$rv{$a}->{seq} <=> $$rv{$b}->{seq} || $a <=> $b } 
             keys %$rv;
    if ($#rv >= 0) {
        return \@rv;
    } else {
        return;
    }
}

sub get_totalnewarticles {
    # for seouri extension
    # by wwolf

    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(SELECT SUM(GREATEST(CAST(a.max_article_no as signed) - CAST(b.article_no as signed), 0))
                 FROM $TBL{board} as a, $TBL{bookmark} as b
                 WHERE b.uid=? && b.board_id=a.board_id);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-uid});
    return $rv;
}

sub get_totalnewcomments {
    # for seouri extension
    # by wwolf

    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(SELECT SUM(GREATEST(CAST(a.max_comment_no as signed) - CAST(b.comment_no as signed), 0))
                 FROM $TBL{board} as a, $TBL{bookmark} as b
                 WHERE b.uid=? && b.board_id=a.board_id);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-uid});
    return $rv;
}

sub get_bookmarkset_by_group { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(SELECT a.board_id, a.title, a.id, a.name, a.is_imgboard,
                        GREATEST(CAST(a.max_article_no as signed) - CAST(b.article_no as signed), 0) as new_articles,
                        GREATEST(CAST(a.max_comment_no as signed) - CAST(b.comment_no as signed), 0) as new_comments,
                        b.article_no,
                        b.comment_no,
                        b.seq, c.gid, c.title as group_title
                 FROM $TBL{board} as a, $TBL{bookmark} as b, $TBL{group} as c
                 WHERE b.uid=? && b.board_id=a.board_id && a.gid=c.gid);

    # 즐겨찾기 목록에 포함할 gid를 명시적으로 지정한다.
    if (exists $arg{-gid} && $arg{-gid})
    {
        my $gid_list = "";
        foreach my $gid ( split(/,/, $arg{-gid}) )
        {
            $gid_list .= $gid . "," if $gid > 0;
        }
        chop $gid_list;
        $sql .= " && a.gid in ($gid_list)" if length($gid_list) > 0;
    }

    # 즐겨찾기 목록에 제외할 gid를 명시적으로 지정한다.
    if (exists $arg{-ex_gid} && $arg{-ex_gid})
    {
        my $gid_list = "";
        foreach my $gid ( split(/,/, $arg{-ex_gid}) )
        {
            $gid_list .= $gid . "," if $gid > 0;
        }
        chop $gid_list;
        $sql .= " && a.gid not in ($gid_list)" if length($gid_list) > 0;
    }

    my $rv = $DBH->selectall_hashref($sql, 'board_id', undef, $arg{-uid});
    my (%boards, %path);
    foreach my $i (sort { $$rv{$a}->{gid} <=> $$rv{$b}->{gid} || 
                          $$rv{$a}->{seq} <=> $$rv{$b}->{seq} ||
                          $a <=> $b } 
                       keys %$rv) {
        my $gid = $$rv{$i}->{gid};
        $path{ $gid } = $gid; 
        delete $$rv{$i}->{gid};
        delete $$rv{$i}->{group_title};
        push @{$boards{ $gid }}, $$rv{$i};
    }
    my $tot = scalar(keys %$rv) + scalar(keys %path);
    my $half = int($tot / 2) + ($tot % 2);
    my (@rv1, @rv2);
    my $count = 0;
    foreach my $i (sort {$a <=> $b} keys %path) {
        my $gsize = scalar(@{$boards{$i}}) + 1;
        if ( ($count < $half && $count + $gsize <= $half) || $tot < 3 ) {
            push @rv1, { path=>$path{$i}, boards=>\@{$boards{$i}} };
        } elsif ($count >= $half) {
            push @rv2, { path=>$path{$i}, boards=>\@{$boards{$i}} };
        } else {
            my $over = $count + $gsize - $half;
            my $mid = $#{$boards{$i}} - $over + 1;
            $mid = 0 if ($mid < 0);
            if ($mid > 0) {
                my @b1 = @{$boards{$i}}[0..$mid-1];
                push @rv1, { path=>$path{$i}, boards=>\@b1 };
            }
            if ($mid <= $#{$boards{$i}}) {
                my @b2 = @{$boards{$i}}[$mid..$#{$boards{$i}}];
                push @rv2, { path=>$path{$i}, boards=>\@b2 };
            }
        }
        $count += $gsize;
    }
    if ($#rv1 >= 0) {
        my @rv = ({ column=>\@rv1 }, { column=>\@rv2 });
        return \@rv;
    } else {
        return;
    }
}

sub get_bookmark_nav {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});
    
    my $bid = $self->board_id || $arg{-board_id} || 0;
    my $sql = qq(SELECT a.board_id, a.title, a.id, a.name, a.is_imgboard,
                        GREATEST(CAST(a.max_article_no as signed) - CAST(b.article_no as signed), 0) as new_articles,
                        GREATEST(CAST(a.max_comment_no as signed) - CAST(b.comment_no as signed), 0) as new_comments,
                        b.article_no,
                        b.comment_no,
                        b.seq
                 FROM $TBL{board} as a, $TBL{bookmark} as b
                 WHERE b.uid=? && b.board_id=a.board_id GROUP BY b.board_id); 
    my $rv = $DBH->selectall_hashref($sql, 'board_id', undef, $arg{-uid});
    my @bms = map { ${$rv}{$_} } 
                  sort { $$rv{$a}->{seq} <=> $$rv{$b}->{seq} || $a <=> $b } 
                  keys %$rv;
    my %bm_nav;
    if (@bms && $#bms >= 0) {
        my $found_next_new_board = 0;
        for (my $i = 0; $i <= $#bms; ++$i) {
            if ($bms[$i]->{board_id} == $bid) {
                my $prev = $i - 1; $prev = $#bms if ($prev < 0);
                my $next = $i + 1; $next = 0 if ($next > $#bms);
                my %prev = %{ $bms[$prev] };
                my %next = %{ $bms[$next] };
                delete @prev{'new_articles', 'new_comments'};
                delete @next{'new_articles', 'new_comments'};
                $bm_nav{prev_board} = [ \%prev ];
                $bm_nav{next_board} =[ \%next ];
                if ($bms[$i]->{new_articles} || $bms[$i]->{new_comments}) {
                    $bm_nav{new_counts} = 1;
                    $bm_nav{new_articles_count} = $bms[$i]->{new_articles};
                    $bm_nav{new_comments_count} = $bms[$i]->{new_comments};
                    #$bm_nav{new_articles} = $bms[$i]->{new_articles};
                    #$bm_nav{new_comments} = $bms[$i]->{new_comments};
                    $bm_nav{last_article_no} = $bms[$i]->{article_no};
                    $bm_nav{last_comment_no} = $bms[$i]->{comment_no};
                }
            } elsif ($found_next_new_board == 0) {
                if ( ($bms[$i]->{new_articles} && $bms[$i]->{new_articles} > 0
) || ($bms[$i]->{new_comments} && $bms[$i]->{new_comments} > 0) ) {
                    $bm_nav{next_new_board} = [ $bms[$i] ];
                    $found_next_new_board = 1
                        if ($bms[$i]->{board_id} > $bid);
                }
            }
        }
    }
    return \%bm_nav;
}

sub set_bookmark { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $a_no = $arg{-article_no} || $self->{max_article_no}; 
    my $c_no = $arg{-comment_no} || $self->{max_comment_no}; 
    my $sql = qq(UPDATE $TBL{bookmark} SET article_no=?, comment_no=? 
                 WHERE board_id=? && uid=?);
    my $rv = $DBH->do($sql, undef, $a_no, $c_no, $arg{-board_id}, $arg{-uid});
    return $rv;
}

sub set_bookmarkset { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(UPDATE $TBL{bookmark} as a, $TBL{board} as b 
                 SET a.article_no=b.max_article_no,a.comment_no=b.max_comment_no
                 WHERE a.board_id=b.board_id && a.uid=?);
    my $rv = $DBH->do($sql, undef, $arg{-uid});
    return $rv;
}

sub set_comment_bookmark { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $comment_no = $arg{-last_comment_no} || $self->{max_comment_no}; 
    my $sql = qq(UPDATE $TBL{bookmark} SET comment_no=? 
                 WHERE board_id=? && uid=?);
    my $rv = $DBH->do($sql, undef, $comment_no, $arg{-board_id}, $arg{-uid});
    return $rv;
}

sub set_article_bookmark { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $article_no = $arg{-article_no} || $self->{max_article_no}; 
    my $sql = qq(UPDATE $TBL{bookmark} SET article_no=? 
                 WHERE board_id=? && uid=?);
    my $rv = $DBH->do($sql, undef, $article_no, $arg{-board_id}, $arg{-uid});
    return $rv;
}

sub add_new_bookmark { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $uid = $arg{-uid};
#    my $ano = $self->{max_article_no};
#    my $cno = $self->{max_comment_no};
    my $ano = &get_max_article_no(board_id => $arg{-board_id});
    my $cno = &get_max_comment_no(board_id => $arg{-board_id});
    my $seq = &get_max_bookmark_seq($uid) + 1;
    my $sql = qq(INSERT INTO $TBL{bookmark} (board_id, uid, article_no, comment_no, seq) VALUES (?, ?, ?, ?, ?));
    my $rv = $DBH->do($sql, undef, $arg{-board_id}, $uid, $ano, $cno, $seq);
    return $rv;
}

sub del_bookmark {
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $sql = qq(DELETE FROM $TBL{bookmark} WHERE uid=? && board_id=?);
    my $rv = $DBH->do($sql, undef, $arg{-uid}, $arg{-board_id});
    return $rv;
}

sub get_new_articles_count { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $sql = qq(SELECT GREATEST(CAST(a.max_article_no as signed) - CAST(b.article_no as signed), 0)
                 FROM $TBL{board} as a, $TBL{bookmark} as b
                 WHERE a.board_id=? && b.board_id=a.board_id && b.uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-board_id}, $arg{-uid});
    return $rv;
}

sub get_new_comments_count { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && exists $arg{-uid});

    my $sql = qq(SELECT GREATEST(CAST(a.max_comment_no as signed) - CAST(b.comment_no as signed), 0)
                 FROM $TBL{board} as a, $TBL{bookmark} as b
                 WHERE a.board_id=? && b.board_id=a.board_id && b.uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-board_id}, $arg{-uid});
    return $rv;
}

sub get_max_bookmark_seq {
    my $uid = shift;
    return unless ($uid);

    my $sql = qq(SELECT MAX(seq) FROM $TBL{bookmark} WHERE uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    if ($rv) {
        return $rv;
    } else {
        return 0;
    }
}

################################################################################
# attach

sub add_attach { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} && 
                   exists $arg{-article_id} &&
                   exists $arg{-file} &&
                   exists $arg{-filename} &&
                   exists $arg{-filesize} &&
                   exists $arg{-content_type} &&
                   exists $arg{-is_img} &&
                   $arg{-filesize} <= ($self->{attach_limit} || 0)
                   );

    my $bid = $arg{-board_id} || 0;
    my $aid = $arg{-article_id} || 0;
    # save to local file system & insert into db
    my $sql = qq(INSERT INTO $TBL{attach} 
                 (board_id, article_id, filename, filesize, content_type, is_img)
                 VALUES (?, ?, ?, ?, ?, ?));
    my $rv = $DBH->do($sql, undef, $bid,
                                   $aid,
                                   $arg{-filename},
                                   $arg{-filesize},
                                   $arg{-content_type},
                                   $arg{-is_img}
                                   );
    &inc_has_attach($aid) if ($rv);
    my $atid = &get_max_attach_id($bid, $aid);
    my @path = $self->attach_file_path($bid, $atid); 
    for (my $i = 1; $i < $#path; $i++) {
        my $dir = File::Spec->catdir(@path[0..$i]);
        $dir =~ m/^([\w.-\\\/]+)$/;
        $dir = $1;
        mkdir($dir) unless (-e $dir);
    }
    my $file = File::Spec->catfile(@path);
    $file =~ m/^([\w.-\\\/]+)$/;
    $file = $1;
    
    open(FH, "> $file") or die("Can't open $file for save: $!\n");
    print FH $arg{-file};
    close FH;
    if ($arg{-is_img} =~ /[yY]/) {
        &add_image_count($bid);
        $self->save_thumbnail($file);
    }
    return $rv;
}

sub del_attach { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-attach_id} && exists $arg{-board_id});

    # delete from db & file system

    my $atid = $arg{-attach_id};
    my $bid = $arg{-board_id};
    my $attach = $self->get_attach(-attach_id=>$atid);
    my $aid = $$attach{article_id} || 0;
    my @path = $self->attach_file_path($bid, $atid);
    my $file = File::Spec->catfile(@path); 
    $file =~ m/^([\w.-\\\/]+)$/;
    $file = $1;
    if (unlink $file) {
        &dec_image_count($bid, $atid);
        my $thumb = $file . 't';
        unlink $thumb;
        my $sql = qq(DELETE FROM $TBL{attach} WHERE attach_id=?);
        my $rv = $DBH->do($sql, undef, $atid);
        &dec_has_attach($aid) if ($rv);
        return $rv;
    }
}

sub del_attachset {
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $attachset = $self->get_attachset(-article_id=>$arg{-article_id});
    my $count = 0;
    foreach my $i (@$attachset) {
        my $rv = $self->del_attach(-board_id=>$$i{board_id}, 
                                   -attach_id=>$$i{attach_id});
        if ($rv) {
            ++$count;
        }
    }
    return $count;
}

sub get_attach { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-attach_id});

    my $atid = $arg{-attach_id};
    my $is_thumb = exists $arg{-thumb} && $arg{-thumb} eq '1' ? 't' : '';
    my $sql = qq(SELECT board_id, article_id, filename, filesize, content_type, is_img
                 FROM $TBL{attach} WHERE attach_id=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $atid);
    if ($rv) {
        my @path = $self->attach_file_path($$rv{board_id}, $atid);
        my $path = File::Spec->catfile(@path) . $is_thumb; 
        if (-s $path) {
            open(FH, "< $path") or die("Can't open $path: $!\n");
            my $filesize = -s FH;
            my %attach = (
                article_id=> $$rv{article_id},
                filename=> $$rv{filename},
                filesize=> $filesize,
                content_type=> $$rv{content_type},
                is_img=> $$rv{is_img},
                filehandle=> *FH,
            );
            $attach{image} = 1 
              if ($$rv{content_type} =~ /image/gi and
                  $$rv{content_type} =~ /gif|jpeg|jpg|png/gi );
            return \%attach;
        } else { warn "$path: $!"; }
        
    }
    return $rv;
}

sub get_attachset { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $sql = qq(SELECT attach_id, board_id, filename, filesize, content_type, is_img
                 FROM $TBL{attach} WHERE article_id=?);
    my $rv = $DBH->selectall_hashref($sql, 'attach_id', undef, $arg{-article_id});
    my @rv;
    foreach my $i (sort { $a <=> $b } keys %$rv) {
        my $ct = $$rv{$i}->{content_type};
        #delete $$rv{$i}->{content_type};
        $$rv{$i}->{image} = 1 
            if ($ct =~ /image/gi && $ct =~ /gif|jpeg|jpg|png/gi);
        $$rv{$i}->{filesize} = &bytes($$rv{$i}->{filesize});
        push @rv, $$rv{$i};
    }
    return \@rv;
}

sub upload_attach {
    my ($self, %arg) = @_;
    return unless (exists $arg{-query});

    my $q = $arg{-query};
    my $attach_no = $q->param('attach_no') || 0;
    return unless $attach_no;
    
    my @attach;
    foreach my $i (1..$attach_no) {
        my $name = 'attach' . $i;
        my $attach = $q->upload($name) || undef;
    
        my %attach;
        if (defined $attach) {
            $attach{filename} = $q->param($name);
            $attach{filename} =~ s/.+[\\\/](.+)$/$1/g;
            $attach{content_type} = $q->uploadInfo($q->param($name))->{'Content-Type'};
            $attach{is_img} = 
                ($attach{content_type} =~ /image/gi and
                 $attach{content_type} =~ /gif|jpeg|jpg|png/gi) ? 'y' : 'n';
            my $buffer;
            while (my $len = read($attach, $buffer, 1024)) {
                $attach{file} .= $buffer;
                $attach{filesize} += $len;
            }
            push @attach, \%attach;
        }
    }
    return \@attach;
}

sub attach_file_path {
    my ($self, $bid, $atid) = @_;

    # organize directories by the last 2 digits of board_id & attach_id to 
    # prevent too many files stored in one directory
    # $attach_dir/board_id last 2 dgts/board_id/attach_id last 2 dgts/attach_id
    my @path = ($self->cfg->AttachDir, $bid % 100, $bid, $atid % 100, $atid);
    return @path;
}

sub img_resize {
    my ($self, %arg) = @_;
    return unless (exists $arg{-image} && exists $arg{-size}); 

    use Image::Magick;
    my $im = new Image::Magick;
    $im->BlobToImage($arg{-image});
    my ($width, $height) = $im->Get('width','height');
    return unless ($width && $height && $width > 0 && $height > 0);
    my $ratio = $width >= $height ? $arg{-size} / $width : $arg{-size} / $height;
    $height = int( $height * $ratio );
    $width = int( $width * $ratio );
    $im->Resize(width=>$width, height=>$height) if ($ratio < 1);
    $im->AutoOrient();
    my $rv = $im->ImageToBlob();
    return $rv;
}

sub inc_has_attach {
    my $article_id = shift;
    my $sql = qq(UPDATE $TBL{head} SET has_attach = has_attach + 1
                 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $article_id);
    return $rv;
}

sub dec_has_attach {
    my $article_id = shift;
    my $sql = qq(UPDATE $TBL{head} SET has_attach = has_attach - 1
                 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $article_id);
    return $rv;
}

################################################################################
# notice

sub add_notice { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $bid = $self->board_id || 0;
    my $aid = $arg{-article_id} || 0;
    my $sql = qq(INSERT INTO $TBL{notice} (board_id, article_id) values (?,?));
    my $rv = $DBH->do($sql, undef, $bid, $aid);
    return $rv;
}

sub del_notice { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $bid = $self->board_id || 0;
    my $aid = $arg{-article_id} || 0;
    my $sql = qq(DELETE FROM $TBL{notice} WHERE board_id=? && article_id=?);
    my $rv = $DBH->do($sql, undef, $bid, $aid);
    return $rv;
}

sub is_notice { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});

    my $bid = $self->board_id || 0;
    my $aid = $arg{-article_id} || 0;
    my $sql = qq(SELECT article_id
                 FROM $TBL{notice} 
                 WHERE board_id=? && article_id=?);
    my $rv = $DBH->selectrow_array($sql, undef, $bid, $aid);
    if ($rv && $rv eq $aid) {
        return 1;
    } else {
        return 0;
    }
}

################################################################################
# Poll

sub add_pollset {
    my ($self, %arg) = @_;
    return unless (exists $arg{-query} && $arg{-query} &&
                   exists $arg{-article_id});
    
    my $q = $arg{-query};
    my $bid = $self->board_id || $arg{-board_id} || 0;
    my $aid = $arg{-article_id} || 0;
    my $dur = $q->param('duration') || 7;
    my @param = $q->param();
    my @poll = sort grep { /^poll\d+$/ } @param;
    my @opt = 
              grep { /^poll\d+_\d+$/ } @param;
    foreach my $i (@poll) {
        my $poll = $q->param($i) || '';
        $poll =~ s/^\s+//g;
        $poll =~ s/\s+$//g;
        my @o = grep { $_ } 
                map { my $t = $q->param($_) || ''; 
                      $t =~ s/^\s+//g; 
                      $t =~ s/\s+$//g;
                      $t; } 
                map { $_->[0] }
                sort { $a->[1] <=> $b->[1] } 
                map { [$_, /(\d+)/] }
                grep { /$i/ && $q->param($_) }
                @opt;
        if ($poll && @o && $#o > 0) {
            my $pid = $self->add_poll(-board_id=>$bid,
                                      -article_id=>$aid,
                                      -duration=>$dur,
                                      -poll=>$poll);
            if ($pid) {
                foreach my $j (@o) {
                    my $rv = $self->add_opt(-poll_id=>$pid, -opt=>$j);
                }
            }
        }
    }

}

sub add_poll {
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id} &&
                   exists $arg{-article_id} &&
                   exists $arg{-duration} &&
                   exists $arg{-poll});

    my ($bid, $aid, $dur) = ($arg{-board_id}, $arg{-article_id}, $arg{-duration});
    $dur = 7 unless ($dur =~ /^[1-9]\d+$/);
    my $sql = qq(INSERT INTO $TBL{poll} 
                 (board_id, article_id, poll, created, closed) 
                 VALUES (?, ?, ?, now(), now() + INTERVAL ? DAY));
    my $rv = $DBH->do($sql, undef, $bid, $aid, $arg{-poll}, $dur);
    if ($rv) {
        &inc_has_poll($aid);
        my $poll_id = get_max_poll_id($bid, $aid);
        return $poll_id;
    } else {
        return 0;
    }
}

sub del_poll {
    my ($self, %arg) = @_;
    return unless (exists $arg{-poll_id} && exists $arg{-article_id});

    my $sql = qq(DELETE $TBL{poll}, $TBL{opt}, $TBL{ans} 
                 FROM $TBL{poll} LEFT JOIN $TBL{opt} USING (poll_id) 
                                 LEFT JOIN $TBL{ans} USING (poll_id) 
                 WHERE $TBL{poll}.poll_id=?);
    my $rv = $DBH->do($sql, undef, $arg{-poll_id});
    &dec_has_poll($arg{-article_id}) if ($rv);
    return $rv;
}

sub del_pollset {
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id});
    my $sql = qq(DELETE $TBL{poll}, $TBL{opt}, $TBL{ans} 
                 FROM $TBL{poll} LEFT JOIN $TBL{opt} USING (poll_id) 
                                 LEFT JOIN $TBL{ans} USING (poll_id) 
                 WHERE $TBL{poll}.article_id=?);
    my $rv = $DBH->do($sql, undef, $arg{-article_id});
    return $rv;
}

sub add_opt {
    my ($self, %arg) = @_;
    return unless (exists $arg{-poll_id} && exists $arg{-opt});

    my $sql = qq(INSERT INTO $TBL{opt} (poll_id, opt) VALUES (?, ?));
    my $rv = $DBH->do($sql, undef, $arg{-poll_id}, $arg{-opt});
    return $rv;
}

sub add_ans {
    my ($self, %arg) = @_;
    return unless (exists $arg{-poll_id} && 
                   exists $arg{-uid} && 
                   exists $arg{-opt_id});

    my $pid = $arg{-poll_id} || 0;
    my $uid = $arg{-uid} || 0;
    my $oid = $arg{-opt_id} || 0;
    
    return 0 if (&is_answered($pid, $uid));
    
    my $sql = qq(INSERT INTO $TBL{ans} (poll_id, uid, opt_id) VALUES (?,?,?));
    my $rv = $DBH->do($sql, undef, $pid, $uid, $oid);
    if ($rv) {
        my $rv2 = &inc_opt_count($oid);
        if ($rv2) { return 1 } else { return 0 }
    } else {
        return 0;
    }
}

sub is_answered {
    my ($pid, $uid) = @_;
    my $sql = qq(SELECT poll_id FROM $TBL{ans} WHERE poll_id=? && uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $pid, $uid);
    if ($rv && $rv == $pid) { return 1 } else { return 0 }
}

sub inc_opt_count {
    my $opt_id = shift;
    my $sql = qq(UPDATE $TBL{opt} SET count = count + 1 WHERE opt_id = ?);
    my $rv = $DBH->do($sql, undef, $opt_id);
    return $rv;
}

sub get_pollset {
    my ($self, %arg) = @_;
    return unless (exists $arg{-article_id} && exists $arg{-uid});

    my $uid = $arg{-uid} || 0;
    my $pid = $arg{-poll_id} || 0;
    my $page = $arg{-page} || 0;
    my $where = $pid ? 'a.article_id=? && a.poll_id=?' : 'a.article_id=?';
    my @arg = ($arg{-article_id});
    push @arg, $pid if ($pid);
    my $sql = qq(SELECT a.poll_id, a.board_id, a.article_id, a.poll,
                        DATE_FORMAT(a.created, '%m/%d') as created,
                        DATE_FORMAT(a.closed, '%m/%d') as closed,
                        a.closed < now() as is_closed,
                        b.uid = $uid as is_owner, $page as page
                 FROM $TBL{poll} as a USE INDEX (article_id) JOIN
                      $TBL{head} as b USE INDEX (PRIMARY) USING (article_id)
                 WHERE $where);
    my $rv = $DBH->selectall_hashref($sql, 'poll_id', undef, @arg);
    my @rv = sort { $a->{poll_id} <=> $b->{poll_id} }
             map { my $is_ans = &is_answered($_, $uid);
                   my $allow_vote = $is_ans || $$rv{$_}->{is_closed} ? 0 : 1;
                   $$rv{$_}->{allow_vote} = $allow_vote;
                   $$rv{$_}->{optset} = &get_optset($_, $uid, $allow_vote);
                   $$rv{$_}->{tot} = $$rv{$_}->{optset}->[0]->{tot} || 0;
                   $$rv{$_}; }
             keys %$rv;
    return \@rv;
}

sub get_optset {
    my ($pid, $uid, $allow_vote) = @_;
    my $sql = qq(SELECT opt_id, poll_id, opt, count
                 FROM $TBL{opt}
                 WHERE poll_id=?);
    my $rv = $DBH->selectall_hashref($sql, 'opt_id', undef, $pid);
    my $tot = 0;
    my @rv = sort { $a->{opt_id} <=> $b->{opt_id} }
             map { $tot += $$rv{$_}->{count}; 
                   $$rv{$_} }
             keys %$rv;

    my $bar_width = 100;
    @rv = map { $_->{pct} = $tot ? sprintf("%.1f", $_->{count} / $tot * 100): "0.0";
                $_->{width} = int($bar_width * $_->{pct} / 100);
                $_->{tot} = $tot;
                $_->{allow_vote} = $allow_vote;
                #####TEMP CODE#####
                #if ($pid == 1427) {
                #if ($pid == 9696 || $pid == 9698) {
                #    $_->{pct} = '';
                #    $_->{width} = '';
                #    $_->{count} = '';
                #}
                #####TEMP CODE#####
                $_; } @rv;
    return \@rv;
}

sub inc_has_poll {
    my $article_id = shift;
    my $sql = qq(UPDATE $TBL{head} SET has_poll = has_poll + 1
                 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $article_id);
    return $rv;
}

sub dec_has_poll {
    my $article_id = shift;
    my $sql = qq(UPDATE $TBL{head} SET has_poll = has_poll - 1
                 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $article_id);
    return $rv;
}

sub get_max_poll_id {
    my ($bid, $aid) = @_;
    my $sql = qq(SELECT max(poll_id) 
                 FROM $TBL{poll}
                 WHERE board_id=? && article_id=?);
    my $rv = $DBH->selectrow_array($sql, undef, $bid, $aid);
    return $rv;
}

################################################################################
# Misc.

sub get_sig {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(SELECT sig FROM $TBL{sig} WHERE uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-uid});

    return $rv;
}

sub edit_sig {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid} && exists $arg{-sig});

    my $sql = qq(REPLACE INTO $TBL{sig} (uid, sig) VALUES (?, ?));
    my $rv = $DBH->do($sql, undef, $arg{-uid}, $arg{-sig});
    if ($rv) {
        return 1;
    } else {
        return 0;
    }

}

sub make_quote_coloring {
    $_ = shift;
    my ($was_inside_html_tag, $is_inside_html_tag, $inside_span) = @_;

    my $text = "";
    if (m/([<>])([^<>]*)$/o) {
        my $a = $1;
        my $b = $2;
        $is_inside_html_tag = (($a eq "<") and ($b =~ m/^[a-z]/io));
    }
    my $who = "님께서 쓰시(길|기를),";
    if( m/(^>.*)|($who)/so ) {
        my $span_end = $is_inside_html_tag ? "" : "</span>";
        $inside_span = not $is_inside_html_tag unless $inside_span;
        if ( m/^(> )(> )(> )(> )((>)(.*)|(.*$who))$/so ) {
            $text .= sprintf "<span class=\"quoted1\">%s</span>", $1 || '';
            $text .= sprintf "<span class=\"quoted2\">%s</span>", $2 || '';
            $text .= sprintf "<span class=\"quoted3\">%s</span>", $3 || '';
            $text .= sprintf "<span class=\"quoted4\">%s</span>", $4 || '';
            $text .= sprintf "<span class=\"quoted5\">%s%s", $5 || '', $span_end || '';
        } elsif ( m/^(> )(> )(> )((>)(.*)?|(.*$who))$/so ) {
            $text .= "<span class=\"quoted1\">$1</span>";
            $text .= "<span class=\"quoted2\">$2</span>";
            $text .= "<span class=\"quoted3\">$3</span>";
            $text .= "<span class=\"quoted4\">$4$span_end";
        } elsif ( m/^(> )(> )((>)(.*)?|(.*$who))$/so ) {
            $text .= "<span class=\"quoted1\">$1</span>";
            $text .= "<span class=\"quoted2\">$2</span>";
            $text .= "<span class=\"quoted3\">$3$span_end";
        } elsif ( m/^(> )((>)(.*)?|(.*$who))$/so ) {
            $text .= "<span class=\"quoted1\">$1</span>";
            $text .= "<span class=\"quoted2\">$2$span_end";
        } elsif ( m/^((>)(.+)?|(.*$who))$/so ) {
            $text .= "<span class=\"quoted1\">$1$span_end";
        } else {
            m/^((>)(.+)?|(.*$who))/so;
            $text .= "<span class=\"quoted5\">$2$3$4$span_end"
                if ($2 && $3 && $4);
        }
    } else {
        $text .= $_;
    }

    if($was_inside_html_tag and not $is_inside_html_tag and $inside_span) {
        chomp $text;
        $text .= "</span>";
        $inside_span = 0;
    }
    $was_inside_html_tag = $is_inside_html_tag;

    return ($text, $was_inside_html_tag, $is_inside_html_tag, $inside_span);
}

sub search_fields { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-field});

    my $field = $arg{-field} || 'title';
    my @search_fields;
    my @field = qw(title);
    push @field, qw(name id) unless ($self->is_anonboard);
    
    foreach my $i (@field) {
        my $checked = $i eq $field ? 1 : 0;
        push @search_fields, { field=>$i, checked=>$checked };
    }
    return \@search_fields;
}

################################################################################
# Tags

sub get_tags { 
    my ($self, %arg) = @_;
    return unless (exists $arg{-board_id});

    my $sql = qq();
    my $rv = $DBH->($sql, undef, $arg{-board_id});
    return $rv;
}

################################################################################
# internal functions

sub init_board {
    my %arg = @_;
    my $bid = $arg{-board_id} || 0;
    my $img = $arg{-img} || 0;
    my $keyword = $arg{-keyword} || '';
    my $field = $arg{-field} || '';
    my $page = $arg{-page} || 0;

    my $sql = qq(SELECT * FROM $TBL{board} WHERE board_id=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $bid);
    $$rv{img} = $img && $img eq '1' ? 1 : 0;
    my $articles;
    if ($keyword && $field && $field =~ /title|name|id/) {
        $articles = &searched_articles($bid, $keyword, $field);
    } elsif ($img && $img eq '1') {
        $articles = $$rv{images};
    } else {
        $articles = $$rv{articles};
    }
    $$rv{tot_page} = &get_tot_page($articles, ${$rv}{article_per_page});
    $$rv{page} = $page ? $page : $$rv{tot_page};
    return $rv;
}

sub init_scrap_board {
    # this is a temporary subroutine!!!
    # scrap functionality should not be implemented like this.
    my %arg = @_;
    $arg{-board_id} = 1;
    my $uid = $arg{-uid}; 
    my $rv = &init_board(%arg);
    $$rv{board_id} = 0;
    $$rv{title} = 'Scrapbook';
    $$rv{articles} = &get_tot_scrap_by_uid($uid);
    $$rv{tot_page} = &get_tot_page($$rv{articles}, $$rv{article_per_page});
    $$rv{page} = $$rv{tot_page} unless $$rv{page} && $$rv{page} <= $$rv{tot_page};
    return $rv;
}

sub searched_articles {
    my ($bid, $keyword, $field) = @_;
    $keyword = &sql_search_pattern_escape($keyword); 
    my $sql = qq(SELECT count(*) 
                 FROM $TBL{head}
                 WHERE board_id=$bid && $field like '\%$keyword%');
    my $rv = $DBH->selectrow_array($sql);
    if ($rv) { return $rv; } 
    else { return 0; }
}

sub sql_search_pattern_escape {
    my $keyword = shift;
    my $esc = $DBH->get_info( 14 ); # SQL_SEARCH_PATTERN_ESCAPE
    $keyword =~ s/([_%'"\+\*\?])/$esc$1/g;
    return $keyword;
}

sub get_tot_page {
    my ($articles, $article_per_page) = @_;
    return 1 unless ($articles && $article_per_page);

    my $tot_page = int( $articles / $article_per_page );
    ++$tot_page if ($articles % $article_per_page);
    $tot_page = 1 if ($tot_page < 1);
    return $tot_page;
}

sub get_start {
    my ($page, $tot_page, $article_per_page) = @_;
    my $start = ($tot_page - $page) * $article_per_page;
    $start = 0 if ($start < 0);
    return $start;
}

sub add_comment_count {
    my ($aid, $bid) = @_;
    my $sql = qq(UPDATE $TBL{head} set comments=comments+1 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $aid);
    $sql = qq(UPDATE $TBL{board} 
              SET max_comment_no=max_comment_no+1 
              WHERE board_id=?);
    $rv = $DBH->do($sql, undef, $bid);
    return $rv;
}

sub dec_comment_count {
    my ($aid) = shift;

    my $sql = qq(UPDATE $TBL{head} set comments=comments-1 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $aid);
    return $rv;
}

sub add_recom_count {
    my ($aid) = shift;

    my $sql = qq(UPDATE $TBL{head} set recom=recom+1 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $aid);
    return $rv;
}

sub add_scrap_count {
    my ($aid) = shift;

    my $sql = qq(UPDATE $TBL{head} set scrap=scrap+1 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $aid);
    return $rv;
}

sub dec_scrap_count {
    my ($aid) = shift;

    my $sql = qq(UPDATE $TBL{head} set scrap=scrap-1 WHERE article_id=?);
    my $rv = $DBH->do($sql, undef, $aid);
    return $rv;
}

sub add_article_count {
    my ($bid) = shift;

    my $sql = qq(UPDATE $TBL{board} 
                 SET articles=articles+1, max_article_no=max_article_no+1 
                 WHERE board_id=?);
    my $rv = $DBH->do($sql, undef, $bid);
    return $rv;
}

sub dec_article_count {
    my ($bid) = shift;

    my $sql = qq(UPDATE $TBL{board} SET articles=articles-1 WHERE board_id=?);
    my $rv = $DBH->do($sql, undef, $bid);
    return $rv;
}

sub add_image_count {
    my ($bid) = shift;

    my $sql = qq(UPDATE $TBL{board} SET images=images+1 WHERE board_id=?);
    my $rv = $DBH->do($sql, undef, $bid);
    return $rv;
}

sub dec_image_count {
    my ($bid, $attach_id) = @_;

    my $sql = qq(UPDATE $TBL{board} as a, $TBL{attach} as b 
                 SET a.images=a.images-1 
                 WHERE a.board_id=? && b.attach_id=? && b.is_img='y');
    my $rv = $DBH->do($sql, undef, $bid, $attach_id);
    return $rv;
}

sub get_max_article_no {
    my %arg = @_;

    my $bid = $arg{board_id} || 0;

    my $sql = qq(SELECT max_article_no FROM $TBL{board} WHERE board_id=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $bid);
   
    return $$rv{max_article_no};
}

sub get_max_comment_no {
    my %arg = @_;

    my $bid = $arg{board_id} || 0;

    my $sql = qq(SELECT max_comment_no FROM $TBL{board} WHERE board_id=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $bid);

    return $$rv{max_comment_no};
}


sub get_max_comment_id {
    my ($bid) = shift;

    my $sql = qq(SELECT MAX(comment_id) FROM $TBL{comment} WHERE board_id=?);
    my $rv = $DBH->selectrow_array($sql, undef, $bid);
    if ($rv) { return $rv; }
    else { return 0; }
}

sub get_next_thread_no {
    my ($bid) = shift;

    my $sql = qq(SELECT MAX(thread_no) FROM $TBL{head} WHERE board_id=?);
    my $rv = $DBH->selectrow_array($sql, undef, $bid);
    if ($rv) { return $rv + 1; }
    else { return 1; }
}

sub get_tot_scrap_by_uid {
    my $uid = shift;
    my $sql = qq(SELECT count(*) FROM $TBL{scrap} WHERE uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    if ($rv) { return $rv; }
    else { return 0; }
}

sub update_max_article_no {
    my $bid = shift;
    my $sql = qq(SELECT MAX(article_no) FROM $TBL{head} WHERE board_id=?);
    my $max_article_no = $DBH->selectrow_array($sql, undef, $bid);
    $sql = qq(UPDATE $TBL{board} SET max_article_no=? WHERE board_id=?);
    my $rv = $DBH->do($sql, undef, $max_article_no, $bid);
    return $rv;
}

sub update_max_comment_no {
    my $bid = shift;
    my $sql = qq(SELECT MAX(comment_no) FROM $TBL{comment} WHERE board_id=?);
    my $max_comment_no = $DBH->selectrow_array($sql, undef, $bid);
    $sql = qq(UPDATE $TBL{board} SET max_comment_no=? WHERE board_id=?);
    my $rv = $DBH->do($sql, undef, $max_comment_no, $bid);
    return $rv;
}

sub update_bookmark {
    my $bid = shift;
    my $sql = qq(UPDATE $TBL{bookmark} a, $TBL{board} b SET a.article_no = b.max_article_no WHERE a.board_id = b.board_id && a.board_id=? && a.article_no > b.max_article_no);
    my $sql2 = qq(UPDATE $TBL{bookmark} a, $TBL{board} b SET a.comment_no = b.max_comment_no WHERE a.board_id = b.board_id && a.board_id=? && a.comment_no > b.max_comment_no);
    my $rv2 = $DBH->do($sql, undef, $bid);
    my $rv = $DBH->do($sql2, undef, $bid);
    return $rv;
}

sub format_article_list {
    my $list = shift;
    
    my (%children, %root);
    foreach my $i (keys %$list) {
        my $parent = $list->{$i}->{parent_no};
        if (exists $list->{$parent} && $i != $parent) {
            ++$children{ $parent }->{ $i };
            ++$root{ $i };
        }
    }
    my( @formated, %done );
    foreach my $i (sort { $b <=> $a } keys %$list) {
        unless (exists $root{ $i }) {
            $list->{$i}->{depth} = "";
            push @formated, $list->{$i};
            push @formated, &traverse($i, 1, \%children, \%done, $list) 
                if (exists $children{ $i } );
        }
    }
    return \@formated;
}

sub traverse {
    my ($parent, $depth, $children, $done, $list) = @_; 
    
    my %children = %$children;
    my %done = %$done if ($done);
    my @list;
    foreach my $i (sort { $a <=> $b } keys %{ $children{ $parent } } ) {
        unless (exists $done{ $i }) {
            ++$done{ $i };
            $list->{$i}->{depth} = "<!---->" . "&nbsp;&nbsp;&nbsp;" x ($depth - 1);
            push @list, $list->{$i};
            push @list, &traverse($i, $depth + 1, \%children, \%done, $list);
        }
    }
    return @list;
}

sub escape_tags {
    my $self = shift;
    $_ = shift;
    my $escaped_tags = $self->{escaped_tags} || 'html body embed iframe applet script bgsound object meta head style link';
    my $tags = '(' . join("|", split(/\s+/, $escaped_tags) ) . ')'; 
    $_ =~ s/<(\/?$tags)/&lt;$1/igox;
    return $_;
}


sub escape_comment_tags {
    my $self = shift;
    $_ = shift;
    my $escaped_tags = $self->{escaped_comment_tags} || 'tr td html body embed iframe applet script bgsound object meta head style link plaintext xmp';
    my $tags = '(' . join("|", split(/\s+/, $escaped_tags) ) . ')'; 
    $_ =~ s/<(\/?$tags)/&lt;$1/igox;
    return $_;
}

sub make_hyperlink {
  use CGI::Util;
  # 2006. 08. 06. modified by wwolf (credit to musiphil)
  my $self = shift;
  $_ = shift;
  my $article = shift || {};
  my $aid = $$article{article_id} || $$article{comment_id} || 0;
  my $title = $$article{title} || "";
  $title =~ s/"/&quote;/g;
  $title =~ s/</&lt;/g;
  $title =~ s/>/&gt;/g;
  my $name  = $$article{name};
  my $id    = $$article{id};
  {
    no warnings; # turn off the warning switch
    #local $^W = 0; # turn off the warning switch
    my $link_url = sub {
      $_ = shift;
      my ($src,$shorten,$domain,$page) = ($_,$_,undef,undef);
      $src = "http://$src" unless m#^https?://#;
      my $src_escaped = CGI::Util::escape($src);
      my $src_session = CGI::Util::escape($src . "?session=" . $self->session_key);
      m# ^ ( https?:// )
          ( [\w\.]* / )
          ( (?:[^\/\?]* /)* )
          ( [^\/\?]* )
          ( \?.* )? 
      #iox and do {
        my @u = (0,$1,$2,$3,$4,$5);
        $domain = $2;
        $page   = $4;
        $u[2] = substr($2, 0, 15) . "../" if length $2 > 17; # domain
        $u[3] = substr($3, 0,  7) . "../" if length $3 >  9; # path
        $u[4] = substr($4, 0, 32) . ".." if length $4 > 34;  # page
        $u[5] = substr($5, 0, 16) . ".." if length $5 > 18;  # query
        $shorten = join("", $1, $2, $3, $4, $5);
        $shorten = join("", $1, $2, $3, $4, $u[5]) if length $shorten > 50;
        $shorten = join("", $1, $2, $u[3], $4, $u[5]) if length $shorten > 50;
        $shorten = join("", $u[1], $u[2], $u[3], $u[4], $u[5]) if length $shorten > 50;
        $shorten = join("", $u[1], $u[2], $u[3], $u[4], $u[5] ? "?.." : "") if length $shorten > 60;
        $shorten = join("", $u[1], $u[2], $u[3] ? "../" : "", $u[4], $u[5] ? "?.." : "") if length $shorten > 65;
        $shorten = join("", $u[1], $u[2], ($u[3] || $u[4] || $u[5] ) ? "..." : "") if length $shorten > 70;
      };
      m! \.(?:jpg|jpeg|gif|png) $ !iogx and
        return qq(<a href="$src" rel="lightbox[embedded-$aid]" title="$title [$1] by $name ($id)" class="auto"><img src="$src" alt="$_"/></a>);
      # Internet Explorer uses the <object> tag, while Firefox, Safari, Chrome, and Opera use the <embed> tag.
      m! \.(?:swf|flv|mp4) $ !iox and $domain =~ m|bawi\.org/$|o and $page eq "attach.cgi" and
        return qq(<a href="$src" target="_blank" title="$src" class="auto">$shorten</a><object class="auto" width="480" height="385" classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"><param name="movie" value="/main/jwplayer/player.swf"></param><param name="allowfullscreen" value="true"></param><param name="allowscriptaccess" value="always"></param><param name="quality" value="best"></param><param name="play" value="false"></param><param name="flashvars" value="file=$src_session"></param><embed class="auto" src="/main/jwplayer/player.swf" allowfullscreen="true" allowscriptaccess="always" quality="best" play="false" flashvars="file=$src_session" width="480" height="385"></embed></object>);
 
      m! \.(?:swf|flv|mp4) $ !iox and
        return qq(<a href="$src" target="_blank" title="$src" class="auto">$shorten</a><object class="auto" width="480" height="385" classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000"><param name="movie" value="/main/jwplayer/player.swf"></param><param name="allowfullscreen" value="true"></param><param name="allowscriptaccess" value="always"></param><param name="quality" value="best"></param><param name="play" value="false"></param><param name="flashvars" value="file=$src_escaped"></param><embed class="auto" src="/main/jwplayer/player.swf" allowfullscreen="true" allowscriptaccess="always" quality="best" play="false" flashvars="file=$src_escaped" width="480" height="385"></embed></object>);

      m#( [^/]+ youtube\.com/watch\?v=([^&\s]+) )#iogx and
        return qq(<a href="$src" target="_blank" title="$src" class="auto">$shorten</a><div class="video-container"><iframe id="ytplayer" type="text/html" src="https://www.youtube.com/embed/$2?fs=1&hl=en_US&rel=0&origin=http://bawi.org" frameborder="0" allowfullscreen></iframe></div>);

      m#( youtu\.be/([^&\s]+) )#iogx and
        return qq(<a href="$src" target="_blank" title="$src" class="auto">$shorten</a><div class="video-container"><iframe id="ytplayer" type="text/html" src="https://www.youtube.com/embed/$2?fs=1&hl=en_US&rel=0&origin=http://bawi.org" frameborder="0" allowfullscreen></iframe></div>);

      m#( vimeo\.com/(\d+) )#iogx and
        return qq(<a href="$src" target="_blank" title="$src" class="auto">$shorten</a><div class="video-container"><iframe class="auto" src="http://player.vimeo.com/video/$2" frameborder="0" allowfullscreen></iframe></div>);
      return qq(<a href="$src" target="_blank" title="$src" class="auto">$shorten</a>);
    };
    # http://daringfireball.net/2010/07/improved_regex_for_matching_urls
    s{
     (?xi)
       #\b  # replaced by line below
       (?: \s | (?<!url)\( | \< | ^) \K # look-behind assertion
     (                       # Capture 1: entire matched URL
       (?:
         https?://               # http or https protocol
         |                       #   or
         www\d{0,3}[.]           # "www.", "www1.", "www2." … "www999."
         |                           #   or
         [a-z0-9.\-]+[.][a-z]{2,4}/  # looks like domain name followed by a slash
       )
       (?:                       # One or more:
         [^\s()<>]+                  # Run of non-space, non-()<>
         |                           #   or
         \(([^\s()<>]+|(\([^\s()<>]+\)))*\)  # balanced parens, up to 2 levels
       )+
       (?:                       # End with:
         \(([^\s()<>]+|(\([^\s()<>]+\)))*\)  # balanced parens, up to 2 levels
         |                               #   or
         [^\s`!()\[\]\{\};:'".,<>?«»“”‘’]        # not a space or one of these punct chars
       )
     )
    } !&$link_url($1)!iogxe;

    s{ ( ^ | (?<=\s|[,;\(\[]) )
       (\#(\d+))
       (?=\s|[,;\.\)\]]|\D|$)
    } !<a href="#c$3" class="auto comment_no">$2</a>!iogx;

  }
  return $_;
}

sub wrap_long_line {
	my $src = shift or return "\n";
	my $attrib = shift || 1; # text(1) or html(2)
    
    $src =~ tr/\r\n/ /; # \r,\n을 space로 바꿈
	my $text = "";
	# 80칼럼을 적당히 잘라낸 후 그 나머지를 다시 $src에 집어넣어
	# 루프를 반복한다. 나머지를 $src에 집어넣을 때에는 $src 앞에
	# 붙은 공백문자를 제거한다. 즉 wrap된 두번째 줄부터는 줄 처음의
	# 공백문자를 없애준다.
	while ( length $src > 0 ) {
		my $len = 79;
		my $line = "";

		# 인용표시(>)는 길이에 포함시키지 않는다.
		if ( $src =~ /^((> )+)/o ) { $len += length($1); }
		# 전체 줄 길이가 5byte를 초과하지 않으면 분리하지 않는다.
		if(length($src) < $len + 5) {
			$src =~ s/\s*$//; # remove trailing spaces
			$text .= $src . "\n";
			last;
		}
		$len = ($len < length($src)) ? $len : length($src);

		INNER: {
		do {
			$src =~ /^(\S+|\s+)/o; # match a first word or spaces
			my $word = $1;
		
			### adjust len value ###
			# make room for HTML character entities (such as "&lt;")
			while($word =~ /(\&\w+;)/go) { $len += length($1) - 1 }
			# make room for HTML tags (such as "<strong>", "</strong">)
			if($attrib == 2) {
				while($word =~ /(<[^>]+>)/go) { $len += length($1) }
			}

			### append word to line ###
			if ( length($line) + length($word) <= $len ) {
				$line .= $word;
				$src = substr $src, length($word), length($src);
			} elsif ( $line =~ /^((> )+|\s+)$/ ) {
				$line .= $word;
				$src = substr $src, length($word), length($src);
			} elsif ( length($line) > 0 ) {
			# It's too long, so push it into next line
				last INNER;
			} else {
			# It's too long but cannot break: take it
				$line .= $word;
				$src = substr $src, length($word), length($src);
			}
		} while ( length($line) < $len and length($src) > 0 );
		}

		$src =~ s/^\s*//o;
		$line =~ s/\s*$//o;
		$text .= $line . "\n";
	}

	return $text;
}

sub bytes {
    my $bytes = shift;

    if ($bytes < 1024) {
        return "$bytes B";
    } elsif ($bytes >= 1024 && $bytes < 1024 ** 2) {
        $bytes = sprintf("%.1f", $bytes / 1024);
        return "$bytes KB";
    } elsif ($bytes >= 1024 ** 2 && $bytes < 1024 ** 3) {
        $bytes = sprintf("%.1f", $bytes / 1024 ** 2);
        return "$bytes MB";
    }
}

sub save_thumbnail {
    my ($self, $file) = @_;
    my $tfile= $file . 't';
    use Image::Magick;
    my $im = new Image::Magick;
    $im->Read($file);
    my ($w, $h) = $im->Get('width', 'height');
    if ($w && $h) {
        my $thumb = $self->{thumb_width} || 100;
        my $scale = $w > $h ? $thumb / $w : $thumb / $h;
        my ($w2, $h2) = (int($w * $scale), int($h * $scale));
        $im->Scale(width=>$w2, height=>$h2);
        my $format = $im->Get('magick');
        $im->Strip;
        $im->Set(quality=>80) if $format eq 'JPEG';
        $im->Write(filename=>$tfile);
    }
}

sub get_max_attach_id {
    my ($bid, $aid) = @_;
    my $sql = qq(SELECT MAX(attach_id) FROM $TBL{attach} 
              WHERE board_id=? && article_id=?);
    my $atid = $DBH->selectrow_array($sql, undef, $bid, $aid);
    return $atid;
}

1;
