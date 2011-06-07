#!/usr/bin/perl -w
################################################################################
# zeroboard2bawix
# converts zeroboard to BawiX
# v0.01: Kyungjoon Lee 2004. 1. 13.
################################################################################


print STDERR <<END;
################################################################################
# 제로보드-BawiX 변환기
################################################################################

제로보도의 설치 디렉토리의 절대경로를 입력해 주세요. 제로보드가 설치되어 있는 
디렉토리로 'cd' 명령을 이용해 이동한 뒤, 'pwd' 명령을 내리면 절대경로를 알 수
있습니다.

프로그램을 종료하려면 <Ctrl + c>를 누르세요.

END

my $zero_install = '';

while (! $zero_install) {
    print STDERR "제로보드 설치 디렉토리: ";
    $zero_install = <STDIN>; 
    chomp($zero_install);
    if (-e $zero_install) {
        my $data = File::Spec->catdir($zero_install, 'data');
        unless (-r $data && -x $data) {
            die <<END;
[$data] 디렉토리에 읽기/실행 권한이 없습니다.

다음과 같이 script/chmod.cgi를 
[$data]에 복사한 뒤
웹브라우저에서 불러주세요. 디렉토리의 읽기/실행 권한을 적절하게 설정합니다.

\$ cp script/chmod.cgi $data

END
        }
    } elsif ($zero_install) {
        print STDERR "[$zero_install]는 존재하지 않는 디렉토리입니다.\n\n";
        $zero_install = '';
    }
}

print STDERR "\n";
################################################################################

use strict;
use File::Spec;
use DBI;

use lib './lib';
use BawiX::UI;
use BawiX::Board;
my $ui = new BawiX::UI;
my $dbh = DBI->connect('dbi:mysql:' . $ui->cfg->DBName, $ui->cfg->DBUser, $ui->cfg->DBPasswd); 
my ($sql, $rv, $sth);

$sql = qq(alter table bw_xboard_comment modify column body text not null default '');
$rv = $dbh->do($sql);

my %ct = (
    'hwp' => 'application/hwp',
    'doc' => 'application/msword',
    'pdf' => 'application/pdf',
    'xls' => 'application/vnd.ms-excel',
    'swf' => 'application/x-shockwave-flash',
    'zip' => 'application/x-zip-compressed',
    'mid' => 'audio/mid',
    'bmp' => 'image/bmp',
    'gif' => 'image/gif',
    'jpg' => 'image/jpeg',
    'png' => 'image/png',
    'tif' => 'image/tiff',
    'htm' => 'text/html',
    'html' => 'text/html',
    'txt' => 'text/plain',
    'asf' => 'video/x-ms-asf',
# application/octet-stream
);
my $ext = join("|", keys %ct);

# 1. zetyx_member_table     -> bw_xauth_passwd, bw_user_sig, bw_group_user
# 2. zetyx_group_table      -> bw_group
# 3. zetyx_admin_table      -> bw_xboard_board
# 4. zetyx_board_*          -> bw_xboard_header/body/comment/attach/notice

##################################################
# 1. zetyx_member_table     -> bw_xauth_passwd, bw_user_sig, bw_group_user

$sql = qq(select no as uid, user_id as id, name, email, comment as sig, group_no as gid, FROM_UNIXTIME(reg_date) as modified from zetyx_member_table);
$rv = $dbh->selectall_hashref($sql, 'uid');

$sql = qq(insert into bw_xauth_passwd (uid, id, name, email, modified, passwd) values (?, ?, ?, ?, ?, ENCRYPT(?)));
my $passwd = $dbh->prepare($sql);

$sql = qq(insert into bw_user_sig (uid, sig) values (?, ?));
my $sig = $dbh->prepare($sql);

$sql = qq(insert into bw_group_user (uid, gid, created) values (?, ?, ?));
my $g_user = $dbh->prepare($sql);

$sql = qq(delete from bw_xauth_passwd where uid=1);
my $del_root = $dbh->prepare($sql);

my $root = exists $$rv{1}->{id} ? $$rv{1}->{id} : 'root'; 
my %user;
foreach my $i (sort { $a <=> $b} keys %$rv) {
    $del_root->execute if $i eq 1;
    my %i = %{$$rv{$i}};
    $i{email} = '' unless $i{email};
    $passwd->execute($i{uid}, $i{id}, $i{name}, $i{email}, $i{modified}, $i{id});
    $sig->execute($i{uid}, $i{sig}) if $i{sig};
    $g_user->execute($i{uid}, $i{gid}, $i{modified});
    $user{ $i{name} }->{uid} = $i{uid};
    $user{ $i{name} }->{id} = $i{id};
    print STDERR "Adding user...", $i{name}, " (", $i{id}, ")\n";
}

print STDERR "\n";


##################################################
# 2. zetyx_group_table      -> bw_group

$sql = qq(select no as gid, name as title from zetyx_group_table);
$rv = $dbh->selectall_hashref($sql, 'gid');

$sql = qq(insert into bw_group (gid, title, keyword, uid, created) values (?, ?, ?, 1, now()));
my $group = $dbh->prepare($sql);

foreach my $i (sort { $a <=> $b} keys %$rv) {
    my %i = %{$$rv{$i}};
    $group->execute($i{gid}, $i{title}, 'g' . $i{gid});
    print STDERR "Adding group...", $i{title}, "\n";
}

print STDERR "\n";

##################################################
# 3. zetyx_admin_table      -> bw_xboard_board

$sql = qq(select no as board_id, group_no as gid, name as keyword, total_article as articles, title, memo_num as article_per_page, page_num as page_per_page, max_upload_size as attach_limit, cut_length as title_length from zetyx_admin_table);
$rv = $dbh->selectall_hashref($sql, 'board_id');

$sql = qq(insert into bw_xboard_board (board_id, gid, keyword, articles, title, article_per_page, page_per_page, attach_limit, title_length) values (?, ?, ?, ?, ?, ?, ?, ?, ?));
my $board = $dbh->prepare($sql);
my %board;
foreach my $i (sort { $a <=> $b} keys %$rv) {
    my %i = %{$$rv{$i}};
    $i{title} = $i{keyword} unless $i{title};
    $board->execute($i{board_id}, $i{gid}, $i{keyword}, $i{articles}, $i{title}, $i{article_per_page}, $i{page_per_page}, $i{attach_limit}, $i{title_length});
    $board{ $i{keyword} } = $i{board_id};
    print STDERR "Adding board...", $i{title} , " [", $i{keyword}, "]\n";
}

print STDERR "\n";

##################################################
# 4. zetyx_board_*          -> bw_xboard_header/body/comment/attach/notice

$sql = qq(insert into bw_xboard_body (article_id, board_id, body) values (?, ?, ?));
my $body = $dbh->prepare($sql);

$sql = qq(insert into bw_xboard_header (article_id, article_no, parent_no, thread_no, board_id, category, title, uid, id, name, count, recom, comments, created) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?));
my $header = $dbh->prepare($sql);

$sql = qq(insert into bw_xboard_comment (comment_no, board_id, article_id, body, uid, id, name, created) values (?, ?, ?, ?, ?, ?, ?, ?));
my $comment = $dbh->prepare($sql);

$sql = qq(insert into bw_xboard_attach (attach_id, board_id, article_id, filename, filesize, content_type, is_img) values (?, ?, ?, ?, ?, ?, ?));
my $attach = $dbh->prepare($sql);

$sql = qq(update bw_xboard_board set images=? where board_id=?);
my $img = $dbh->prepare($sql);

$sql = qq(update bw_xboard_board set max_article_no=?, max_comment_no=? where board_id=?);
my $max_no = $dbh->prepare($sql);

my $aid = 1;
my $atid = 1;
my @notice;
foreach my $i (sort { $board{$a} <=> $board{$b} } keys %board) {
    print STDERR "Converting [$i]...";
    $sql = qq(select no as article_no, father as parent_no, category, subject as title, memo as body, name, hit as count, vote as recom, total_comment as comments, FROM_UNIXTIME(reg_date) as created, headnum, s_file_name1 as file1, s_file_name2 as file2, file_name1 as path1, file_name2 as path2 from zetyx_board_$i);
    my %a = %{ $dbh->selectall_hashref($sql, 'article_no') };

    $sql = qq(select no as comment_id, parent as article_no, name, memo as body, FROM_UNIXTIME(reg_date) as created from zetyx_board_comment_$i);
    my %c = %{ $dbh->selectall_hashref($sql, 'comment_id')};
    
    my %aid;
    my $bid = $board{$i};
    my $articles = 0;
    my $images = 0;
    my $max_ano = -1;
    my $xb = new BawiX::Board;
    foreach my $j (sort { $a <=> $b} keys %a) {
        my %j = %{$a{$j}};
        $j{parent_no} = $j{article_no} unless $j{parent_no};
        my $uid = $user{ $j{name} }->{uid} || 0;
        my $id = $user{ $j{name} }->{id} || 'guest';
        $j{title} =~ s/\\('|")/$1/g;
        $j{body} =~ s/\\('|")/$1/g;
        $header->execute($aid, $j{article_no}, $j{parent_no}, $j{parent_no}, $bid, $j{category}, $j{title}, $uid, $id, $j{name}, $j{count}, $j{recom}, $j{comments}, $j{created});
        $body->execute($aid, $bid, $j{body});
        $aid{ $j{article_no} } = $aid;
        $max_ano = $j{article_no} if ($j{article_no} > $max_ano);
        if ($j{headnum} && $j{headnum} <= -2000000000) {
            push @notice, [$bid, $aid]
        }
        foreach my $k (1..2) {
            if ($j{"file$k"}) {
                my $f = $j{"file$k"};
                $f =~ /($ext)$/i;
                my $ct = $1 ? $ct{lc($1)} : 'application/octet-stream';
                $ct = 'application/octet-stream' unless $ct;
                my $is_img = $f =~ /(jpg|gif|png|jpeg)$/i ? 'y' : 'n';
                my $path = $zero_install . "/" . $j{"path$k"};
                if (my $size = -s $path) {
                    my @path = ($ui->cfg->AttachDir, $bid % 100, $bid, $atid % 100);
                    for (my $p = 1; $p <= $#path; $p++) {
                        my $dir = File::Spec->catdir(@path[0..$p]);
                        $dir =~ m/^([\w.-\\\/]+)$/;
                        $dir = $1;
                        mkdir($dir) unless (-e $dir);
                    }
                    my $file = join("/", @path, $atid);
                    `cp "$path" "$file"`;
                    if (-s $file) {
                        $attach->execute($atid, $bid, $aid, $f, $size, $ct, $is_img);
                        if ($is_img eq 'y') {
                            $xb->save_thumbnail($file);
                            ++$images;
                        }
                        ++$atid;
                    }
                }
            }
        }
        ++$aid;
        ++$articles;
    }
    my $comment_no = 1;
    foreach my $j (sort { $a <=> $b} keys %c) {
        my %j = %{$c{$j}};
        my $uid = $user{ $j{name} }->{uid} || 0;
        my $id = $user{ $j{name} }->{id} || 'guest';
        $j{body} =~ s/\\('|")/$1/g;
        $comment->execute($comment_no, $bid, $aid{ $j{article_no} }, $j{body}, $uid, $id, $j{name}, $j{created});
        ++$comment_no;
    }
    $img->execute($images, $bid) if ($images);
    $max_no->execute($max_ano, $comment_no, $bid);
    print STDERR "$articles articles, $comment_no comments, $images images\n"; 
}

$sql = qq(insert into bw_xboard_notice (board_id, article_id) values (?, ?));
my $notice = $dbh->prepare($sql);
foreach my $i (@notice) {
    $notice->execute(@$i);
}

print STDERR "\n";
print <<END;
모든 회원의 비밀번호는 아이디와 동일하게 설정되었습니다.
BawiX에 처음으로 접속할 때 비밀번호를 변경하도록 설정되었습니다.

END

print STDERR "관리자 아이디  : $root\n";
print STDERR "관리자 비밀번호: $root\n";
print STDERR "\n";
print <<END;
이제 웹브라우저를 이용해 BawiX에 접속을 하실 수 있습니다. 
END

1;
