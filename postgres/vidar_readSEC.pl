#!/usr/bin/env perl
use strict;
use warnings;
use DBI;

# $/ = "";  # paragraph mode

print  STDERR "Start of Program\n" ;

print  STDERR "Setting up DB connection\n" ;

# set for unbuffered output
$| = 1;

# Prepare connection to database.
my $dbh = DBI->connect(
    "dbi:Pg:dbname=vidar",
    "jpb",  # adjust username
    "semajj123",          # adjust password
    { AutoCommit => 1, RaiseError => 1 }
) or die "Can't connect: $DBI::errstr";

# Prepared statement for offenders table.
my $sth = $dbh->prepare(
    "INSERT INTO offenders (offense_time, offender_ip, desc_line, entry, context, rule_num, evidence) 
     VALUES (?, ?::inet, ?, ?, ?, ?, ?)"
);


# Prepared statement for ipfw_queue table.
# The blocking time comes through as an integer number of seconds to block (e.g. 3600 seconds).
# The below syntax creates the correct removal time from that value.
my $ipfwq = $dbh->prepare(
    "INSERT INTO ipfw_queue (ip_addr, blocktime, added_at, remove_after)
     VALUES (?::inet, ?, now(), now() + (? * interval '1 second'))"
);


# Prepared statement for repeaters table.
# This is an "UPSERT" - i.e. insert new or update existing record.
my $rep = $dbh->prepare(q{
  INSERT INTO repeaters (offender_ip, repeat_count, first_seen, last_seen)
  VALUES (?, 1, ?, ?)
  ON CONFLICT (offender_ip)
  DO UPDATE SET repeat_count = repeaters.repeat_count + 1,
  last_seen                  = now()
});



print  STDERR "Ready for input\n" ;

while (<STDIN>) {
    my $inputline = $_;
    chomp;
    next if /^\s*$/;

# DEBUGGING
    print STDERR "[$inputline]\n";
    
    # $blocktime is an integer number of seconds to block the IP.
    # Each sec rule has it's own blocktime value or 0 (permanent block). See below.
    my ($time, $ip, $desc, $entry, $context, $rule, $blocktime, $evidence) = split /\|/, $_, 8;
    
    # Sanitize inputs
    unless (defined $time && $time =~ /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}$/) {
        warn "Invalid timestamp format: $time\n";
        next;
    }
    
    unless (defined $ip && $ip =~ /^[\d\.:a-fA-F]+$/) {
        warn "Invalid IP format: $ip\n";
        next;
    }
    
    unless (defined $rule && $rule =~ /^\d+$/) {
        warn "Invalid rule number: $rule\n";
        next;
    }
    
    # logs can be anything - no shell execution risk in INSERT
    
# DEBUGGING ONLY
    print STDERR "Inserting record into offenders table for rule [$rule]\n";

    eval {
        $sth->execute($time, $ip, $desc, $entry, $context, $rule, $evidence);
    };
    if ($@) {
        warn "Insert into offenders failed: $@";
        next;
    }

    # Only execute this entry if the block is NOT zero.
    # Zero (0) is a permanent block, so don't enter here, just pass the IP through.
    # By not adding the record here, it will land into ipfw and never be removed.
    if ($blocktime != 0) {
      print STDERR "Blocking [$ip] in ipfw_queue table for [$blocktime] on rule [$context, $rule]\n";
      eval {
          $ipfwq->execute($ip, $blocktime, $blocktime);
      };
      if ($@) {
          warn "Insert into ipfw_queue failed: $@";
          next;
      }
    }
    else {
      print STDERR "Blocking [$ip] permanently on rule [$context, $rule]\n";
    }


    print STDERR "UPSERTING  record for repeaters table on [$ip]\n";

    eval {
        $rep->execute($ip, $time, $time);
    };
    if ($@) {
        warn "Insert into repeaters failed: $@";
        next;
    }


    # Send validated IP to add2BAD.pl script.
    print STDOUT "$ip\n";
}


print STDERR "End of Program.  Closing DB connection\n";

$sth->finish();
$dbh->disconnect();
