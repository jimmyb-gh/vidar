#!/usr/local/bin/perl

# randomip.pl - generate a valid random IP address.

# usage: perl randomip.pl  highest_byte number_of_reps throttle  R|6|4  N
#  ARGV                          0            1           2        3    4

$| = 1;  #piping hot

$numargs = scalar @ARGV;

if((scalar @ARGV) != 5) {
  print "usage: perl randomip.pl highest_byte number_of_reps throttle_seconds R|6|4 N\n";
  exit 1;
}

srand;


$count = 0;

# understand arguments

$max4 = $ARGV[0];

if ($max4 >= 255) {
  $max4 = 255;
} 

$max6 = 0x3000;

$repititions = $ARGV[1];

$repititions == 0 ? 1 : $repititions;

# throttle using select() so value can be fractional
$throttle = $ARGV[2];
if ($throttle == 0) {
    $throttle = 1;    # default is one second
}

# If there is an R - explicitly set random v4/v6 IP
$randvar = $ARGV[3];
if ($randvar =~ /R/i) {
    $rando = 1;
}
elsif ($randvar == 6) {
    $rando = 6
}
elsif ($randvar == 4) {
    $rando = 4
}
else {
    $rando = 4
}


# Check for numbered standard output
$numbered = $ARGV[4];
if ($numbered =~ /n/i) {
    $numbered = 1;    # output is to be numbered
}

while ($repititions-- > 0) {

  if($rando == 1 ) {
      $iptype = int(rand(2));
  }
  elsif ($rando == 6) {
      $iptype = 1;
  }
  else {
      $iptype = 0;
  }

  $count++;

  if( $iptype == 0) {
      $a = int(rand($max4));
      $b = int(rand($max4));
      $c = int(rand($max4));
      $d = int(rand($max4));
      if ($numbered == 1) {
          $outline = sprintf("%-06.6d| %d\.%d\.%d\.%d", $count, $a, $b, $c, $d);
      }
      else {
          $outline = sprintf("%d\.%d\.%d\.%d", $a, $b, $c, $d);
      }
  }
  else {
      $max = 0x3000;
      $a = int(rand($max6));
      $b = int(rand($max6));
      $c = int(rand($max6));
      $d = int(rand($max6));
      $e = int(rand($max6));
      $f = int(rand($max6));
      $g = int(rand($max6));
      $h = int(rand($max6));
      if ($numbered == 1) {
          $outline = sprintf("%-06.6d| %4.4X:%4.4X:%4.4X:%4.4X:%4.4X:%4.4X:%4.4X:%4.4X",
          $count, $a, $b, $c, $d, $e, $f, $g, $h)
      }
      else {
          $outline = sprintf("%4.4X:%4.4X:%4.4X:%4.4X:%4.4X:%4.4X:%4.4X:%4.4X",
          $a, $b, $c, $d, $e, $f, $g, $h)
      }
  }
  print STDERR  "$count: $outline\n";
  print STDOUT  "$outline\n";

  # fractional throttle 
  select (undef, undef, undef, $throttle);
}


