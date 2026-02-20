#!/usr/bin/env perl
use strict;
use warnings;
use DBI;

# $/ = "";  # paragraph mode

print  STDERR "Start of Program\n" ;

print  STDERR "Setting up DB connection\n" ;

# set for unbuffered output
$| = 1;

my $dbh = DBI->connect(
    "dbi:Pg:dbname=vidar",
    "jpb",  # adjust username
    "semajj123",          # adjust password
    { AutoCommit => 1, RaiseError => 1 }
) or die "Can't connect: $DBI::errstr";

my $sth = $dbh->prepare(
    "INSERT INTO offenders (offense_time, offender_ip, desc_line, entry, context, rule_num, evidence) 
     VALUES (?, ?::inet, ?, ?, ?, ?, ?)"
);


print  STDERR "Ready for input\n" ;

while (<STDIN>) {
    my $inputline = $_;
    chomp;
    next if /^\s*$/;

# DEBUGGING
    print STDERR "[$inputline]\n";
    
    my ($time, $ip, $desc, $entry, $context, $rule, $evidence) = split /\|/, $_, 7;
    
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
    print STDERR "Inserting record for rule [$rule]\n";

    eval {
        $sth->execute($time, $ip, $desc, $entry, $context, $rule, $evidence);
    };
    if ($@) {
        warn "Insert failed: $@";
        next;
    }
    
    # Send validated IP to privileged updater
    print STDOUT "$ip\n";
}

# out jpbclose $ipfw_pipe;

print STDERR "End of Program.  Closing DB connection\n";

$sth->finish();
$dbh->disconnect();
