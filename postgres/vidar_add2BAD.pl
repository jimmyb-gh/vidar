#!/usr/bin/env perl
use strict;
use warnings;

# Run as root via sudo or setuid wrapper
# Only accepts IPs on STDIN, one per line

# set unbuffered output
$| = 1;

print STDERR "Start of vidar_add2BAD.pl\n";

my $ip = "";

while (<STDIN>) {

    my $inputline = $_;

    chomp $inputline;

# DEBUGGING
    print STDERR "Received $inputline\n";
    
    # Strict validation - only valid IPs
    next unless $inputline =~ /^([\d\.]+|[:\da-fA-F]+)$/;
    $ip = $1;  # untaint

    
    # Safe execution - no shell interpolation
    system('/sbin/ipfw', '-q', 'table', 'BAD', 'add', $ip);
    
    if ($? != 0) {
        print "[$?]\n";
        my $exit_code = $? >> 8;
        print STDERR "IPFW add failed (exit $exit_code) for $ip\n";
    }
# DEBUGGING
    print STDERR "Added [$ip]\n\n";
}

print STDERR "End of vidar_add2BAD.pl\n";
