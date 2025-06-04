#!/usr/local/bin/perl

use strict;
use warnings;

my $test = $ARGV[0];

print "[$test]\n";

my $retest = '^[0-9a-fA-F:]+$';

if ( $test =~ /$retest/ ) {
    print "MATCHED!\n";
} else {
    print "no match.\n";
}

