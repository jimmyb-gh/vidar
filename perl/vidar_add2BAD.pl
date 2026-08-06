#!/usr/bin/env perl
use strict;
use warnings;
use Socket qw(AF_INET AF_INET6 inet_pton);
use IO::Socket::INET;  # used for sending UDP packets to Leaflet mapper via socat(1).


# Run as root via sudo or setuid wrapper
# Accepts input of "ip|permanent_block"  on STDIN.
# The permanent block status can be passed to Leaflet mapper.

sub send_map_event {
  my($offender_ip, $permanent_block) = @_;

  my $socket = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1',
    PeerPort => 5514,
    Proto    => 'udp',
  );

  # Mapping is optional, Never stop Vidar if the socket can't be created.
  return if !defined $socket;

  my $message = "$offender_ip|$permanent_block\n";

  $socket->send($message);
  $socket->close();
}



# set unbuffered output
$| = 1;

sub valid_ip {
  my ($ip) = @_;
  return defined inet_pton(AF_INET,  $ip)
      || defined inet_pton(AF_INET6, $ip);
}

print STDERR "Start of vidar_add2BAD.pl\n";

my $ip = "";
my $permanent_block = 0;
my $offender_ip = "";

while (<STDIN>) {

    my $inputline = $_;

    chomp $inputline;

# DEBUGGING
    print STDERR "Received $inputline\n";
    
    ($ip, $permanent_block) = split('|', $inputline,2);

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
        # Send packet to Leaflet mapper.
        send_map_event($offender_ip,$permanent_block);
    }
}

print STDERR "End of vidar_add2BAD.pl\n";
