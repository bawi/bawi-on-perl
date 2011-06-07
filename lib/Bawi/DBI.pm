package Bawi::DBI; 
    
use strict;
use warnings;

use DBI;
use Carp qw(cluck);

sub new {
    my ($class, %arg) = @_;

    my $cfg = $arg{-cfg};
    my $dbname = $arg{-dbname} || $$cfg{DBName} || '';
    my $dbuser = $arg{-dbuser} || $$cfg{DBUser} || '';
    my $dbpasswd = $arg{-dbpasswd} || $$cfg{DBPasswd} || '';

    my $dbh = $dbname && $dbuser && $dbpasswd ?
        DBI->connect("dbi:mysql:$dbname", $dbuser, $dbpasswd) : undef;

    #my $self = { dbh => $dbh };
    #bless $self, $class;
    return $dbh;
}   
    
1;
