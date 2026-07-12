#!/usr/bin/env perl
use strict;
use warnings;
use Socket qw(AF_INET AF_INET6 inet_pton);


# Run as root via sudo or setuid wrapper
# Only accepts IPs on STDIN, one per line

# set unbuffered output
$| = 1;

sub valid_ip {
  my ($ip) = @_;
  return defined inet_pton(AF_INET,  $ip)
      || defined inet_pton(AF_INET6, $ip);
}

print STDERR "Start of vidar_add2BAD.pl\n";

my $ip = "";

while (<STDIN>) {

    my $inputline = $_;

    chomp $inputline;

# DEBUGGING
    print STDERR "Received $inputline\n";
    
    # Strict validation - only valid IPs
    unless (valid_ip($inputline)) {
      warn "Invalid IP format: [$inputline]\n";
      next;
    }
    $ip = $inputline;  # untaint

    
    # Safe execution - no shell interpolation
    system('/sbin/ipfw', '-q', 'table', 'BAD', 'add', $ip);
    
    if ($? != 0) {
        print "[$?]\n";
        my $exit_code = $? >> 8;
        print STDERR "IPFW add failed (exit $exit_code) for $ip\n";
    }
    else {
# DEBUGGING
        print STDERR "Added [$ip]\n\n";
    }
}

print STDERR "End of vidar_add2BAD.pl\n";
