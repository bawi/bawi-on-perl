# Copyright (c) 2002 BAWI. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Bawi::Main::RecentAccess;
$VERSION = 0.1;
use strict;
use warnings;
use Carp;
use DBI;

use vars qw($DBTABLE $TIME $DBTABLE_HISTORY);
$DBTABLE = "bw_user_access";
$DBTABLE_HISTORY = "bw_user_access_history";
$TIME = 60;

sub new {
    my ($class,%args) = @_;
    bless {
        -dbh => $args{-dbh},
	},$class;
}

sub DESTROY {
    my $self = shift;
    $self->{'-dbh'}->disconnect;
}
################################################################################
# methods
#

sub set_last_access2 {
    my $self = shift;
	my $uid = shift || "";
	my $id = shift || "";

    #print "Content-type: text/html\n\n";
    #print "uid = $uid, id = $id<br>";
	return if ($id eq "" && $uid eq "" );

    my $stmt = qq(SELECT uid, last_access, count,
                         last_access - ( now() - interval 90 second - 0 ) 
                            as timediff
                         from $DBTABLE where id = ?);
    use Data::Dumper;
    #print $stmt;
    #print "uid = $uid, id = $id<br>";
	  my $rv = $self->{'-dbh'}->selectall_arrayref($stmt, undef, $id);
    #print "Content-type: text/html\n\n";
    #print Dumper $rv;
    if( scalar( @{$rv} ) > 0 ) {
    # ¿¿ ¿¿ ID
        my $last_access = $rv->[0]->[1];
        my $count = $rv->[0]->[2];
        my $timediff = $rv->[0]->[3];
        if( $timediff < 0 ) {
        # ¿¿¿ ¿¿ check ¿¿ 90 ¿ ¿¿ ¿¿¿¿ history¿ ¿¿¿¿ count¿ 0¿¿ setting
            my $stmt_history = "insert into $DBTABLE_HISTORY ( uid, last_access, id, count ) values ( ?, ?, ?, ? )";
            my $sth_history = $self->{'-dbh'}->prepare( $stmt_history );
	        my $rv_history = $sth_history->execute($uid, $last_access, $id, $count );

	        $stmt = "UPDATE $DBTABLE SET id = ?, last_access = now(), count = 1  where uid = ?";
        } else {
	        $stmt = "UPDATE $DBTABLE SET id = ?, count = count + 1  where uid = ?";
        }
    } else {
	    $stmt = "INSERT INTO $DBTABLE ( id, uid, last_access, count ) values ( ?, ?, now(), 0 )";
        #print $stmt;
    }
    #print "<br>stmt : $stmt";
	my $sth = $self->{'-dbh'}->prepare($stmt);
	$rv = $sth->execute($id, $uid);
	return $rv;
}

# obsoleted by set_last_access2()
sub set_last_access {
    my $self = shift;
	my $uid = shift || "";
	my $id = shift || "";

    #print "uid = $uid, id = $id<br>";
	return if ($id eq "" && $uid eq "" );

    my $stmt = "SELECT uid from $DBTABLE where id = ?";
    use Data::Dumper;
    #print $stmt;
    #print "uid = $uid, id = $id<br>";
	my $rv = $self->{'-dbh'}->selectall_arrayref($stmt, undef, $id);
    #print "Content-type: text/html\n\n";
    #print Dumper $rv;
    if( scalar( @{$rv} ) > 0 ) {
	    $stmt = "UPDATE $DBTABLE SET id = ?, count = count + 1  where uid = ?";
        #print $stmt;
    } else {
	    $stmt = "INSERT INTO $DBTABLE ( id, uid, last_access, count ) values ( ?, ?, now(), 0 )";
        #print $stmt;
    }
	my $sth = $self->{'-dbh'}->prepare($stmt);
	$rv = $sth->execute($id, $uid);
	return $rv;
}

sub get_topten {
    my $self = shift;
    my $time = shift;
	
	my $stmt = "SELECT u.uid, u.id, u.name FROM bw_user_access a, bw_xauth_passwd u where a.uid = u.uid and last_access > now() - interval $time second order by count desc limit 10";
	my $rv = $self->{'-dbh'}->selectall_arrayref($stmt);
    return @$rv;
}

sub check_last_access {
    my $self = shift;
    my $time = shift;
	
	my $stmt = "SELECT u.uid, u.id, u.name FROM bw_user_access a, bw_xauth_passwd u where a.uid = u.uid and last_access > now() - interval $time second";
	my $rv = $self->{'-dbh'}->selectall_arrayref($stmt);
    return @$rv;
}

1;
