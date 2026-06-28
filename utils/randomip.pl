#!/usr/local/bin/perl

# randomip.pl - generate a valid random IP address.

sub usage() {
  print STDERR << 'EOUSAGE';
usage: perl randomip.pl  highest_byte number_of_reps throttle  6|4|R  N|x  [L]
 ARGV                          0            1           2        3    4     5

 "highest byte" is the highest first octet to generate for IPv4 addresses
 "number of reps" is how many you want to generate
 "throttle" is how fast you want to generate them.  throttle can be fractional (e.g. 0.1)
 "6|4|R" is whether you want all IPv6, all IPv4, or a random mix of the two.
 "N|x" is whether you want output lines numbered on STDOUT
 "L" (optional) is whether you want random IP addresses (x) or addresses locked to
    documentation addresses (see RFC 3849)
EOUSAGE

  exit 1;
}




$| = 1;  #piping hot

$numargs = scalar @ARGV;

if((scalar @ARGV) != 6) {
   usage; 
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
    $rando = 6;
}
elsif ($randvar == 4) {
    $rando = 4;
}
else {
    $rando = 4;
}

# Check for numbered standard output
$numbered = $ARGV[4];
if ($numbered =~ /n/i) {
    $numbered = 1;    # output is to be numbered
}

# Lockdown mode for IPv6. See below.
$lockdown = $ARGV[5];
if ($lockdown =~ /L/i) {
   $lockmedown = 1;
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
      $a == 0 ? $a += 1 : $a;
      if ($numbered == 1) {
          $outline = sprintf("%-06.6d| %d\.%d\.%d\.%d", $count, $a, $b, $c, $d);
      }
      else {
          $outline = sprintf("%d\.%d\.%d\.%d", $a, $b, $c, $d);
      }
  }
  else {
      if ($lockmedown == 0) {   # be random
          $max6 = 0x3000;
          $a = int(rand($max6));
          $b = int(rand($max6));
          $c = int(rand($max6));
          $d = int(rand($max6));
          $e = int(rand($max6));
          $f = int(rand($max6));
          $g = int(rand($max6));
          $h = int(rand($max6));
      }
      else {  # lock down to 2001:db8::_last_hextet_ between 0 and 0xFF
          $max6 = 0xFF;
          $a = 0x2001;
          $b = 0x0db8;
          $c = 0;
          $d = 0;
          $e = 0;
          $f = 0;
          $g = 0; 
          $h = int(rand($max6));
          } 
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


