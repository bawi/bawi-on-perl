#!/usr/bin/perl -w
use strict;
use File::Spec;

print "Content-type: text/plain\n\n";

my $dir = $0 =~ m!(.*[/\\])! ? $1 : './'; 
if (opendir(DIR, $dir)) {
    my @dir= grep { /^[^\.]/ && -d File::Spec->catdir($dir, $_) } readdir(DIR);
    closedir DIR;
    push @dir, '.';
    foreach my $i (@dir) {
       my $d = File::Spec->catdir($dir, $i);
       `chmod 705 $d`; 
       print "chmod 705 $d\n"; 
    }
} else {
    print "Can't opendir $dir: $!\n";
}

