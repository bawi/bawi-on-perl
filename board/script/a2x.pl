#!/usr/bin/perl -w
###########################################
# a2x.pl : Aragorn Board to BawiX Board 
###########################################
# v0.1.0 : by seouri
# v0.1.1 : Modified by JikhanJung 20041210
# v0.1.2 : Modified by HyungkyuKwon 20050119
###########################################

use strict;
use DBI;

my ($dbname, $dbuser, $dbpasswd) = ('doslove', 'doslove', 'password');
my $dbh = DBI->connect("dbi:mysql:$dbname",$dbuser, $dbpasswd); 

my $board_insert = $dbh->prepare( qq(insert into bw_xboard_board ( keyword, title, id, name ) values ( ?, ?, ?, ? )));
my $header_insert = $dbh->prepare(qq(insert into bw_xboard_header (article_no, thread_no, parent_no, created, count, id, name, title, board_id, uid) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)));
my $body_insert = $dbh->prepare(qq(insert into bw_xboard_body (article_id, board_id, body) values (?, ?, ?)));
my $update_board = $dbh->prepare(qq(update bw_xboard_board set articles=? where board_id=?));
my $update_board2 = $dbh->prepare(qq(update bw_xboard_board set max_article_no=? where board_id=?));

my @board;
@board = @ARGV;

if( scalar( @board ) == 0 ){
opendir DIR, ".";
my @l_dirs = readdir DIR;
closedir DIR;
foreach my $l_dir ( @l_dirs ) {
    next unless -d $l_dir;
    next unless -e "$l_dir/index";
    next unless -s "$l_dir/index" > 0;
    push( @board, $l_dir );
}
}
my $aid = 1;
foreach my $board (@board) {
	open(FH, "< $board/index") or die("Can't open $board/index: $!\n");
	my $thread_no = 1;
	my @index;
	my (%tno, %ano, %pno);
	my $tno = 1;
	my $ano = 1;
        print "Enter name of the board '$board': ";
        my $boardname = <stdin>;
        chomp $boardname;
        $board_insert->execute( $board, $boardname, 'root', 'root' );
	my $bid = $dbh->{'mysql_insertid'};
	while (<FH>) {
		chomp;
		my @t = split(/\|/);
		push @index, { tno=>$t[0], ano=>$t[1] }; 
		$ano{ $t[1] } = $ano++;
		unless (exists $tno{ $t[0] }) {
			$tno{ $t[0] } = $tno++;
			$pno{ $t[0] } = $ano{ $t[1] };
		}


	}
	close FH;

    my $articles = 0;
	foreach my $i (@index) {
		my ($ano, $tno, $pno) = ($ano{ $$i{ano} }, $tno{ $$i{tno} }, $pno{ $$i{tno} });
		my @d = localtime($$i{ano});
		my $created = sprintf("%4d-%02d-%02d %02d:%02d:%02d", $d[5] + 1900, $d[4] + 1,  @d[3, 2, 1, 0]);
		my ($count, $title, $id, $name, $body) = &get_article($board, $$i{ano});
		$header_insert->execute($ano, $tno, $pno, $created, $count, $id, $name, $title, $bid, 1);
		$body_insert->execute($aid, $bid, $body);
		#print join("\t", $ano, $tno, $pno, $created, $count, $id, $name, $title, $bid), "\n";
		++$aid;
        ++$articles;
	}
    $update_board->execute($articles, $bid);
    $update_board2->execute($articles, $bid);
	print $aid - 1, " articles..\n";
	++$bid;
}

sub get_article {
	my ($board, $ano) = @_;
	open(FH, "< $board/$ano") or die("Can't open $board/$ano: $!\n");
	my $header = <FH>;
	my $skip = <FH>;
	my @body = <FH>;
	my $body = join("", @body);
	close FH;
	my @t = split(/\|/, $header);
	my @h = @t[6..9];

	return (@h, $body);
}

