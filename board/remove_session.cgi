#!/usr/bin/perl -w
use strict;
use lib '../lib';
use CGI;

use Bawi::Auth;
use Bawi::Board::Config;
use Bawi::Board::UI;
use Bawi::DBI;
use overload;

my $q = new CGI;
my $cfg = new Bawi::Board::Config;
my $auth = new Bawi::Auth(-cfg => $cfg);

my ($session_key) =
    map { $q->param($_) || undef } qw( session_key );


sub objectToString {
    my $obj    = shift; # object to convert to string
    my $indent = shift; # indentation level. Defaults to 0.

    $indent = 0 unless( defined( $indent ));
    return 'undef' unless( defined( $obj ));

    my $ret = '';

    my $strval = overload::StrVal( $obj );

    my ($realpack, $realtype, $id) = ($strval =~ /^(?:(.*)\=)?([^=]*)\(([^\(]*)\)$/);
    $realpack = '' unless( $realpack );
    $realtype = '' unless( $realtype );
    $id = '' unless( $id );

    if( $realpack eq "Math::BigInt" ) {
        $ret .= ref( $obj ) . " { ";
        $ret .= $obj->bstr;
        $ret .= " }";
    } elsif( $realtype eq "ARRAY" ) {
        $ret .= ref( $obj ) . " {\n";
        # check whether this is a pseudo-hash
        if( @{$obj} && overload::StrVal( @{$obj}[0] ) =~ m!^pseudohash=! ) {
            my $pseudo = @{$obj}[0];
            foreach my $k ( keys %{$pseudo} ) {
                $ret .= indent( $indent+1 );
                $ret .= sprintf( "%-32s => %s\n", $k, objectToString( @{$obj}[ $pseudo->{$k} ], $indent+1 ));
            }
        } else {
            foreach my $o ( @{$obj} ) {
                $ret .= indent( $indent+1 );
                if( ref( $o ) eq "HASH" || ref( $o ) eq "ARRAY" ) {
                    $ret .= objectToString( $o, $indent+1 ) . "\n";
                } else {
                    if( defined( $o )) {
                        $ret .= objectToString( $o, $indent+1 ) . "\n";
                    } else {
                        $ret .= "<<undef>>\n";
                    }
                }
            }
        }
        $ret .= indent( $indent ) . "}\n";

    } elsif( $realtype eq "HASH" ) {
        $ret .= ref( $obj ) . " {\n";
        foreach my $k ( keys %{$obj} ) {
            $ret .= indent( $indent+1 );
            $ret .= sprintf( "%-32s => %s\n", $k, objectToString( $obj->{$k}, $indent+1 ));
        }
        $ret .= indent( $indent ) . "}";
    } else {
        $ret .= $obj;
    }
    return $ret;
}

#####
# indent so many times
sub indent {
    my $indent = shift;

    $indent = 0 unless( defined( $indent ));
    my $ret = '';
    for( my $i=0 ; $i<$indent ; ++$i ) {
        $ret .= '    ';
    }
    return $ret;
}


if ($auth->auth) {
	print $session_key;
	#my $sql = qq(SELECT id FROM bw_xauth_session WEERE session_key=?);
	#my $rv = $DBH->selectrow_hashref($sql, undef, $session_key);
	print objectToString($auth->get_session($session_key));
	#print $session_key;
#	print $ss->{id};
	print "~".$auth->id();
  	#$auth->del_session($session_key);
  	#print $q->redirect("mysessions.cgi");
} else {
  	#print $q->redirect("mysessions.cgi");
}

exit;
