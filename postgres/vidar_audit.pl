#!/usr/bin/env perl
use strict;
use warnings;
use DBI;
#
# usage: perl vidar_audit.pl  
#
# This script reads entries in the offenders table and compares them
# to entries in the active IPFW BAD table.
# The script lists out which are in the database with active_block = 1
# but are not in the IPFW BAD table and vice versa.
# 
#

# KEEP THIS FOR SOME FUTURE REASON
#my $numargs = scalar @ARGV;
#
#if((scalar @ARGV) != 1) {
#  print STDERR "usage: perl vidar_sweepIPFW.ps throttle_seconds\n";
#  print STDERR "       throttle_seconds can be a fractional value \n";
#  exit 1;
#}
#

print  STDERR "Start of Program\n" ;

## Understand arguments.
## Throttle uses select() so value can be fractional.
#
#my $throttle = $ARGV[0];
#
#unless (defined $throttle && $throttle =~ /^\d+(?:\.\d+)?$/) {
#    die "Invalid throttle value [$throttle]\n";
#}
#
#if ($throttle == 0) {
#    $throttle = 0.5;    # default is one half second
#}
#

print  STDERR "Setting up DB connection\n" ;

# Set for unbuffered output.  Piping Hot!
$| = 1;

my $dbh = DBI->connect(
    "dbi:Pg:dbname=vidar",
    "postgres",
    undef,
    {
        RaiseError     => 1,
        PrintError     => 0,
        AutoCommit     => 1,
        pg_enable_utf8 => 1,
    }
) or die "Can't connect: $DBI::errstr";


#$dbh->{FetchHashKeyName} = 'NAME_lc';

# Prepared sweep statement for offenders table.
# Look for entries that have active_block = 1.
# These should include all those that are permanently blocked.
# The statement selects all rows that meet the criteria.
# Below it is accessed as a hash table.

# Sweep the table for expired entries, output the oldest first.
my $sth = $dbh->prepare(
   "select offender_ip \
       from offenders where \
       active_block = 1 \
    order by offender_ip asc"
);

## This statement updates the ipfw_removed_at field if the actual ipfw
## removal (see system() call below) succeeded.
#
#my $updh = $dbh->prepare (
#   "update offenders \
#        set 
#          active_block = 0, \
#          ipfw_removed_at = now() \
#    where
#          offender_ip = ?
#      and permanent_block = 0
#      and active_block = 1
#      and ipfw_removed_at is null"
#);
#

# Execute the select statement
eval {
    $sth->execute();
};

if ($@) {
    warn "Select statement failed!: $@";
    exit;
}


my $hash_ref = ();

my $ip_addr = "";
my %db_hash = ();

my $dbcount = 0;

print  STDERR "Retrieving records from offenders\n";

while ( $hash_ref = $sth->fetchrow_hashref ) {

# DEBUGGING
    #print STDERR "[ip_addr is $hash_ref->{'offender_ip'}]\n";

    $ip_addr = $hash_ref->{'offender_ip'};

    $db_hash{$ip_addr} = "P";  # Assign the hash keyed by the ip address the value "P".

    print ".";

#    # Fractional throttle.
#    select (undef, undef, undef, $throttle);

   $dbcount++;
}

print "\nCount of database records: [$dbcount]\n\n";

print STDERR "Closing DB connection\n\n";

# Clean up.
$sth->finish();
$dbh->disconnect();


# print out the db hash

# DEBUGGING
#print "Printing the db_hash\n";

#foreach my $db_key (sort keys %db_hash) {
#  print "dbkey [$db_key] : value $db_hash{$db_key}  ";
#}

my $ipfwcount = 0;

print "Extracting the IPFW BAD table\n\n";
# Now get the IPFW list
my @ipfw_array = `/sbin/ipfw table BAD list`;

my %ipfw_hash = ();

print "Converting the IPFW BAD table to hash\n";

my $ipfw_ipaddr = "";

foreach my $a  (@ipfw_array) {
  chomp $a;
  ($ipfw_ipaddr, my $junk) = split /\//,$a,2;
#DEBUGGING
  #print "ipfw_ipaddr: [$ipfw_ipaddr]  ";
  $ipfw_hash{$ipfw_ipaddr} = "P";
  print ".";
  $ipfwcount++;
}

print "\nCount of IPFW records: [$ipfwcount]\n";

#DEBUGGING
#foreach my $ipfw_key (sort keys %ipfw_hash) {
#  print "ipfwkey [$ipfw_key] : value $ipfw_hash{$ipfw_key}  ";
#}

print "\nComparing Database to IPFW:\n";

foreach my $a (sort keys %db_hash) {
  my $db   = $db_hash{$a} ? $db_hash{$a} : "NoValue";
  my $ipfw = $ipfw_hash{$a} ? $ipfw_hash{$a} : "NoValue";

  if ( "X${db}" eq "X${ipfw}") {
    next;
  }
  else {
    print "Database entry [$a] not found in IPFW table\n";
  }
}


print "\nComparing IPFW  to Database:\n\n";

foreach my $a (sort keys %ipfw_hash) {
  my $ipfw = $ipfw_hash{$a} ? $ipfw_hash{$a} : "NoValue";
  my $db   = $db_hash{$a} ? $db_hash{$a} : "NoValue";

  if ( "X${ipfw}" eq "X${db}") {
    next;
  }
  else {
    print "IPFW entry [$a] not found in DB table\n";
  }

}
print "End of Program\n";


