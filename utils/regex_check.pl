#!/usr/local/bin/perl

use strict;
use warnings;

my $testpattern = $ARGV[0];

my $inputline = "";

while(1)
{
  print "Enter a line: ";
  $_ = <STDIN>;
  chomp $_;

  $inputline = $_;

  print "Inputline: [$inputline]\n";


  if ( $inputline =~ /$testpattern/i ) {
      print "MATCHED!\n";
      print "one   = [$1]\n";
      print "two   = [$2]\n" if $2;
      print "three = [$3]\n" if $3;
      print "four  = [$4]\n" if $3;
  } else {
      print "no match.\n";

    }
}
