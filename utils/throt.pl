#!/usr/local/bin/perl

# throt.pl  read stdin put and write to stdout under a throttle.

# usage: perl randomip.pl throttle
#  ARGV                     0

$| = 1;  #piping hot

$numargs = scalar @ARGV;

if((scalar @ARGV) != 1) {
  print "usage: perl throttle_seconds\n";
  exit 1;
}

srand;


# understand arguments


# throttle using select() so value can be fractional
$throttle = $ARGV[0];
if ($throttle == 0) {
    $throttle = 1;    # default is one second
}


while (<STDIN>) {

   $outline = $_;

#  print STDERR  "$outline"; # cr/lf was not stripped
  print STDOUT  "$outline"; # cr/lf was not stripped

  # fractional throttle 
  select (undef, undef, undef, $throttle);
}


