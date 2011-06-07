#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Board;
use Bawi::Board::UI;
use Digest::MD5 qw(md5_hex);

my $ui = new Bawi::Board::UI(-template=>'rss.tmpl');
my $q = $ui->cgi;
my $t = $ui->template;
my $cfg = $ui->cfg;

my $uid = $q->param('uid') || undef;
my $code = $q->param('code') || undef;
my $e_code = md5_hex($uid, $cfg->DBPasswd, $cfg->DBName, $cfg->DBUser, $cfg->AttachDir)
    if ($uid);

if ($uid && $code && $code eq $e_code) {
    my $xb = new Bawi::Board(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
    my $bmset = $xb->get_bookmarkset(-uid=>$uid);
    my @mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @wday = qw(Mon Tue Wed Thu Fri Sat Sun);
    if ($bmset) {
        my @d = gmtime;
        # Sat, 07 Sep 2002 00:00:01 GMT
        my $pubDate = sprintf("%s, %02d %s %d %02d:%02d:%02d %s", $wday[$d[6] - 1], $d[3], $mon[$d[4]], $d[5] + 1900, $d[2], $d[1], $d[0], 'GMT' );;
        $t->param(pubDate=>$pubDate);
        my $cgiurl = $ui->cgi->url;
        my $bmurl = $cgiurl;
        $bmurl =~ s/rss.cgi/bookmark.cgi/g;
        my $readurl = $cgiurl;
        $readurl =~ s/rss.cgi/read.cgi/g;
        $t->param(link=>$bmurl);
        my @item;
        my $count = 1;
        foreach my $i (@$bmset) {
            my %item;
            my $new = '';
            $new .= $$i{new_articles} if ($$i{new_articles});
            $new .= " [" . $$i{new_comments} . "]" if ($$i{new_comments});
            $item{title} = qq($count. $$i{title}: $new);
            $item{description} = $$i{title};
            $item{link} = qq($readurl?bid=$$i{board_id};la=$$i{article_no};lc=$$i{comment_no});
            $item{author} = qq($$i{name} ($$i{id}));
            $item{pubDate} = $pubDate;
            if ($$i{new_articles} || $$i{new_comments}) {
                push @item, \%item;
                ++$count;
            }
        } 
        if ($count == 1) {
            my %item = (
                title       => 'No updates',
                description => 'No updates',
                link        => $bmurl,
                author      => 'none',
                pubDate     => $pubDate,
            );
            push @item, \%item;
        }
        $t->param(item=>\@item);
    }
}
print $q->header(-type=>'text/xml', -charset=>$cfg->CharSet);
print $t->output;
1;
