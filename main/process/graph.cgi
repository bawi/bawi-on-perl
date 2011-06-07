#!/usr/bin/perl -w

# added by Jikhan JUNG to support various options
# modified by aragorn, 2002/07/08
#    changed load scale and integrated daily graph and last-24-hour graph
# changed load scale by doslove, 2010/02/09

use strict;

use lib '../lib';
use vars qw($DIR);
use CGI qw(:standard);
use GD;

my $q = new CGI;
my $date = $q->param( 'date' );
my $date_str;
if ($date) {
    $date_str = join("-", unpack("a4a2a2", $date));
} else {
    $date_str = "during last 24 hours";
}


$DIR = $ENV{BAWI_PERL_HOME}."/admin/process/dat";

my $interval = 1; # horizontal interval of 1 pixel

my (%one, %five, %fifteen);
my $factor = 8; # vertical interval of 8 pixel
my $load_scale = 0.1;
my $user_scale = 10;
my $scale = $factor * 2;

$| = 1;

my @lines = read_data($date, $date_str);
=rem
my $file = $DIR . "/" . $date_str . ".txt";
open(FILE, "< $file") or die("Can't open $file: $!\n");
while(<FILE>) {
	chomp;
	push @lines, $_;
}
close FILE;
=cut

print header(-type=>"image/png");

my $width = 1470;
my $height = $factor * 20 + 10; # 20 intervals + lower margin of 10 pixels
my $im = new GD::Image ($width + 20, $height + 20);
my $white = $im->colorAllocate (255, 255, 255);
my $red   = $im->colorAllocate (255, 0, 0);
my $green = $im->colorAllocate (0, 204, 0);
my $blue  = $im->colorAllocate (0, 0, 255);
my $black = $im->colorAllocate (0, 0, 0);
my $gray  = $im->colorAllocate (204, 204, 204);
my $orange = $im->colorAllocate (255, 153, 0);

my $color_load_1  = $im->colorAllocate (  0, 255, 255);
my $color_load_5  = $im->colorAllocate (  0,   0, 255);
my $color_load_15 = $im->colorAllocate (  0, 255,   0);
my $color_user    = $im->colorAllocate (255,   0,   0);

my @origin = (20, $height);


my @data;
my $sum = 0;
foreach (@lines) {
	chomp;
	push @data, [split(/\t+/, $_)];
	
	$sum += $data[$#data]->[1];
}

my $average_load = int( $sum / ( scalar( @data ) || 1 ) * 100 ) / 100;
my $sd;
my( $sd_sum, $max_load ) = (0, 0);
foreach( @data ) {
	my $z = ( $average_load - $_->[1] );
	$max_load = $_->[1] if( $_->[1] > $max_load );
	my $zz = $z * $z;
	$sd_sum += $zz;
}
$sd = int( sqrt( $sd_sum / ( scalar( @data ) || 1 ) ) * 100 ) / 100;

my $start = $#data - 1440 + 1; $start = 0 if $start < 0;
draw_frame($im, $start);

for(my $i = $start; $i < $#data; $i += $interval) {
#for(my $i = $#data; $i >= $start; $i -= $interval) {
	my $gone0     = int(($data[$i-$interval]->[1] || 0) * $factor / $load_scale);
	my $gfive0    = int(($data[$i-$interval]->[2] || 0) * $factor / $load_scale);
	my $gfifteen0 = int(($data[$i-$interval]->[3] || 0) * $factor / $load_scale);
	my $guser0    = int(($data[$i-$interval]->[4] || 0) * $factor / $user_scale);
	my $gone1     = int(($data[$i]->[1] || 0) * $factor / $load_scale);
	my $gfive1    = int(($data[$i]->[2] || 0) * $factor / $load_scale);
	my $gfifteen1 = int(($data[$i]->[3] || 0) * $factor / $load_scale);
	my $guser1    = int(($data[$i]->[4] || 0) * $factor / $user_scale);

	$im->line($i - $start + $origin[0],     $height - $gone0,
              $i - $start + $origin[0] + 1, $height - $gone1,   $color_load_1);
	$im->line($i - $start + $origin[0],     $height - $gfive0,
              $i - $start + $origin[0] + 1, $height - $gfive1,  $color_load_5);
	$im->line($i - $start + $origin[0],     $height - $gfifteen0,
              $i - $start + $origin[0] + 1, $height - $gfifteen1, $color_load_15);
	$im->line($i - $start + $origin[0],     $height - $guser0,
              $i - $start + $origin[0] + 1, $height - $guser1,  $color_user);
}



print $im->png;

if ($date) {
    open( HISTORY, ">history/$date_str.png" );
    print HISTORY $im->png;
    close HISTORY;
}
exit;

sub draw_frame {
  my $im = shift;
  my $start = shift;

  $im->rectangle(@origin, $width, $height, $black);
  
  # x-axis
  $im->line (@origin, $width + $origin[0], $origin[1], $black);
  
  # y-axis
  $im->line (@origin, $origin[0], $origin[1] - $height, $black);
  $im->line ($origin[0] + $width - 30, $origin[1], $origin[0] + $width - 30, $origin[1] - $height, $black);
  
  # y labels along with y-axis
  for (my $y_axis=0; $y_axis <= $height; $y_axis += $factor) {
      # for every another index
      if ( $y_axis % ($factor * 2) == 0 ) {
  
          my $ylabel_left  = $y_axis / $factor * $load_scale;
          my $ylabel_right = $y_axis / $factor * $user_scale;
          $im->string (gdSmallFont, 0,             $origin[1] - $y_axis - 10,
                      "$ylabel_left", $black);
          $im->string (gdSmallFont, $width - 7,   $origin[1] - $y_axis - 10, 
                      "$ylabel_right", $black);
  
          # draw vertical lines
  	    $im->line($origin[0],       $origin[1] - $y_axis,
                    $width - 15,      $origin[1] - $y_axis, $gray) unless $y_axis == 0;
      }
  
  	$im->line ( $origin[0] ,    $origin[1] - $y_axis,
  		        $origin[0] + 3, $origin[1] - $y_axis,
  		        $black  );
  	$im->line ( $origin[0] + $width - 30, $origin[1] - $y_axis,
  		        $origin[0] + $width - 33, $origin[1] - $y_axis,
  		        $black  );
  }
  
  # x labels along with x-axis
  for (my $x_axis=0; $x_axis <= $width; $x_axis = int($x_axis + 60 / $interval)) {
      $im->line ( $x_axis + $origin[0],
                     $origin[1] - 3,
                     $x_axis + $origin[0],
                     $origin[1],
                     $black );
  	my $xlabel = $data[$x_axis + $start]->[0] || "";
  	$im->string (gdSmallFont, $x_axis, $height, "$xlabel", $black);
  }
  
  $im->string (gdSmallFont, $origin[0] + 60 / $interval * 24 - 20, $height, "current", $red);
      
  $im->string (gdSmallFont, $origin[0] + 10, 0, "System Load Average: $date_str "
                                               . "Average $average_load SD $sd "
                                               . "MaxLoad $max_load", $black);
  $im->string (gdSmallFont, $origin[0] + 10, 12, "1", $color_load_1);
  $im->string (gdSmallFont, $origin[0] + 17, 12, "/", $black);
  $im->string (gdSmallFont, $origin[0] + 24, 12, "5", $color_load_5);
  $im->string (gdSmallFont, $origin[0] + 31, 12, "/", $black);
  $im->string (gdSmallFont, $origin[0] + 38, 12, "15", $color_load_15);
  $im->string (gdSmallFont, $origin[0] + 56, 12, "min average,", $black);
  $im->string (gdSmallFont, $origin[0] + 132, 12, "concurrent users", $color_user);

}

sub read_data {
    my $date = shift;
    my $date_str = shift;

    my @loads;
    if ( $date ) {
        my $file = $DIR . "/" . $date_str . ".txt";
        open(FILE, $file) or die("Can't open $file: $!");
        while(<FILE>) {
            chomp;
            push @loads, $_;
        }
        close FILE;
    } else {
        foreach(0..1) {
            my @ftime = localtime(time - 86400 + $_ * 86400);
            my $load = $DIR . "/" . sprintf("%04d-%02d-%02d", $ftime[5]+1900, $ftime[4]+1, $ftime[3]) . ".txt";
            if(-e $load) {
                open(FILE, $load) or die("Can't open $load: $!");
                while(<FILE>) {
                    chomp;
                    push @loads, $_;
                }
                close FILE;
            }
        }

        splice(@loads, 0, -1440); # 1440 = 24 * 60
    }

    return @loads;
}
