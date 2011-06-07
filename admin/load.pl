#!/usr/bin/perl -w
# record system load average and number of login-user
# This script is executed every minute by the crond. 
use strict;
use lib "../lib";

use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-main_dir=>'admin', -template=>"passwd.tmpl");
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $online = $auth->online_bawi;

# data directory
my $dir = $ENV{BAWI_PERL_HOME}."/admin/process/dat";

# data file name: ex) 2001-05-09.txt
my @ftime = localtime(time);
my $file = $dir . "/" . sprintf("%04d-%02d-%02d", $ftime[5]+1900, $ftime[4]+1, $ftime[3]) . ".txt";

my @time = localtime(time);
my $time = sprintf("%02d:%02d", $time[2], $time[1]);

open(FILE, ">> $file") or die("Can't open $file: $!\n");
my @uptime = split(/: /, `uptime`);
$uptime[1] =~ s/, /\t/g; chomp $uptime[1];
my $count = scalar( @$online );
print FILE $time, "\t", $uptime[1], "\t", $count, "\n";
close FILE;

1;
__END__

sub get_server_load {
        my $proc_loadavg = "/proc/loadavg";
        open(LOADAVG, $proc_loadavg) or return undef;
        my $loadavg = <LOADAVG>; chomp $loadavg;
        close(LOADAVG);  
        
        my ($load, undef) = split(/\s/, $loadavg, 2);
        return $load;
}
