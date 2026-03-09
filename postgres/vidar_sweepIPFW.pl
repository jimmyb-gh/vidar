#!/usr/bin/env perl
use strict;
use warnings;
use DBI;


#
# usage: perl vidar_sweepIPFW.pl throttle
#  ARGV                     0

my $numargs = scalar @ARGV;

if((scalar @ARGV) != 2) {
  print STDERR "usage: perl vidar_sweepIPFW.ps throttle_seconds blocktime\n";
  print STDERR "       throttle_seconds can be a fractional value \n";
  print STDERR "       blocktime is the amount of time the ip is supposed to be blocked.\n";
  exit 1;
}

# Prime the RNG.
srand;

print  STDERR "Start of Program\n" ;

# Understand arguments.
# Throttle uses select() so value can be fractional.
my $throttle = $ARGV[0];
if ($throttle == 0) {
    $throttle = 0.5;    # default is one half second
}

my $blocktime_value = $ARGV[1];
if ($blocktime_value == 0) {
    $blocktime_value =  3600;    # default is one hour
}



print  STDERR "Setting up DB connection\n" ;

# Set for unbuffered output.  Piping Hot!
$| = 1;

# Prepare connection to database.
my $dbh = DBI->connect(
    "dbi:Pg:dbname=vidar",
    "jpb",  # adjust username
    "semajj123",          # adjust password
    { AutoCommit => 1, RaiseError => 1 }
) or die "Can't connect: $DBI::errstr";

#$dbh->{FetchHashKeyName} = 'NAME_lc';

# Prepared sweep statement for ipfw_queue table.
# Look for entries that have aged out based on the command line variable blocktime_value.
my $sth = $dbh->prepare(
    "select * from ipfw_queue where remove_after <  now() - interval '5 minutes' and blocktime <= ? order by remove_after desc"
);


# Prepared delete statement for ipfw_queue table.
# Look for entries that have aged out.
my $delh = $dbh->prepare(
    "delete from ipfw_queue where ip_addr = ? and blocktime <= ?"
);


# Execute
eval {
    $sth->execute($blocktime_value);
};

if ($@) {
    warn "Select statement failed!: $@";
    exit;
}


print  STDERR "Retrieving records from ipfw_queue\n";

my @row;
my $hash_ref = ();
my $ip_addr = "";

# while ( @row = $sth->fetchrow_array ) {
while ( $hash_ref = $sth->fetchrow_hashref ) {

# DEBUGGING
#    print STDERR "[@row]\n";
#    print STDERR "[ip_addr is $hash_ref->{'ip_addr'}\tblocktime is $hash_ref->{'blocktime'}\tremove_after is $hash_ref->{'remove_after'}]\n";

    $ip_addr = $hash_ref->{'ip_addr'};

#    # Send validated IP to add2BAD.pl script.
#    print STDOUT "$ip\n";

   # Safe execution - no shell interpolation
    print STDERR "system('/sbin/ipfw', '-q', 'table', 'BAD', 'delete', $ip_addr);\n";


    system('/sbin/ipfw', '-q', 'table', 'BAD', 'delete', $ip_addr);


    # Delete from ipfw_queue

    print STDERR "Delete $ip_addr from ipfw_queue\n";

    # Execute
    eval {
        $delh->execute($ip_addr, $blocktime_value);
    };

    if ($@) {
        warn "Delete statemetn failed!: $@";
        exit;
    }

    # Fractional throttle.
    select (undef, undef, undef, $throttle);


}

print STDERR "End of Program.  Closing DB connection\n";

$sth->finish();
$dbh->disconnect();

