#!/usr/bin/env perl
use strict;
use warnings;
use DBI;
use POSIX qw(WIFSIGNALED WTERMSIG);
#
# usage: perl vidar_sweepIPFW.pl throttle
#
# This script reads entries in the offenders table that are aged out.
# It retrieves the ip address of such entries and calls a script to delete
# the ip address of the ipfw BAD table.
# It does NOT delete the entries from the database, but it does update the record.
# We want the historical record maintained.
#


my $numargs = scalar @ARGV;

if((scalar @ARGV) != 1) {
  print STDERR "usage: perl vidar_sweepIPFW.ps throttle_seconds\n";
  print STDERR "       throttle_seconds can be a fractional value \n";
  exit 1;
}

# Check environment for sane dev or production values,
# and pull libexec into a variable.
#
my $vidar_home    = $ENV{VIDAR_HOME};
my $vidar_libexec = $ENV{VIDAR_LIBEXEC};

print STDERR "vidar_home    = [${vidar_home}]\n";
print STDERR "vidar_libexec = [${vidar_libexec}]\n";


# Prime the RNG.
srand;

my $shutdown_requested = 0;

sub termhandler()
{
  print STDERR "Signal TERM received.  Exiting after current operation\n";
  $shutdown_requested = 1; 
   
}

sub inthandler()
{
  print STDERR "Signal INT received.  Exiting after current operation\n";
  $shutdown_requested = 1; 
}

$SIG{INT}  = \&inthandler;
$SIG{TERM} = \&termhandler;


print  STDERR "Start of Program\n" ;

# Understand arguments.
# Throttle uses select() so value can be fractional.

my $throttle = $ARGV[0];

unless (defined $throttle && $throttle =~ /^\d+(?:\.\d+)?$/) {
    die "Invalid throttle value [$throttle]\n";
}

if ($throttle == 0) {
    $throttle = 0.5;    # default is one half second
}


print  STDERR "Setting up DB connection\n" ;

# Set for unbuffered output.  Piping Hot!
$| = 1;

my $dbh = DBI->connect(
    "dbi:Pg:dbname=vidar",
    undef,
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
# Look for entries that have aged out based on the remove_after field in the database
# but are NOT permanently blocked (permanent_block == 1).
# The statement selects all rows that meet the criteria.
# Below it is accessed as a hash table.

# Sweep the table for expired entries, output the oldest first.
#    print STDERR "[ip_addr is $hash_ref->{'offender_ip'}\tblock_seconds is $hash_ref->{'block_seconds'}\tremove_after is $hash_ref->{'remove_after'}]\n";

my $sth = $dbh->prepare(
   "select offender_ip, block_seconds, active_block, remove_after \
       from offenders where \
           remove_after <  now() - interval '5 minutes' \
       and permanent_block = 0  \
       and active_block = 1 \
       and ipfw_removed_at is NULL \
    order by remove_after asc"
);

# This statement updates the ipfw_removed_at field if the actual ipfw
# removal (see system() call below) succeeded.

my $updh = $dbh->prepare (
   "update offenders \
        set 
          active_block = 0, \
          ipfw_removed_at = now() \
    where
          offender_ip = ?
      and permanent_block = 0
      and active_block = 1
      and ipfw_removed_at is null"
);


# Execute the select statement
eval {
    $sth->execute();
};

if ($@) {
    warn "Select statement failed!: $@";
    exit;
}

print  STDERR "Retrieving records from offenders\n";

my $hash_ref = ();
my $ip_addr = "";

while ( $hash_ref = $sth->fetchrow_hashref ) {

  last if $shutdown_requested;

# DEBUGGING
#    print STDERR "[ip_addr is $hash_ref->{'offender_ip'}\tblock_seconds is $hash_ref->{'block_seconds'}\tremove_after is $hash_ref->{'remove_after'}]\n";

    $ip_addr = $hash_ref->{'offender_ip'};

#    # Show ip address we are about to remove from ipfw.
#    print STDOUT "$ip_addr\n";

   # Safe execution - no shell interpolation
   #print STDERR "system('/sbin/ipfw', '-q', 'table', 'BAD', 'delete', $ip_addr);\n";

    # Call helper script to actually delete entry from IPFW.
    my $rc = system("/usr/local/bin/sudo",
             "${vidar_libexec}/vidar_ipfw_delete.sh",
             $ip_addr);

    if ($shutdown_requested) {
        print STDERR "Shutdown requested. Leaving sweep loop.\n";
        last;
    }

    if (WIFSIGNALED($rc)) {
        my $sig = WTERMSIG($rc);
        warn "vidar_sweepIPFW.pl: child command killed by signal $sig\n";

        if ($sig == 2 || $sig == 15) {   # SIGINT or SIGTERM
            print STDERR "Child was interrupted. Exiting sweeper.\n";
            last;
        }
    }

       # Success. Execute the update statement




    if ($rc == 0) {
       eval {
           $updh->execute($ip_addr);
       };

       if ($@) {
           warn "Update statement failed!: $@";
           exit;
       }
    }
    else {
        warn "vidar_sweep_IPFW.pl: failed to delete $ip_addr from ipfw: $?\n"; 
        #exit;
    }

    if ($shutdown_requested) {
      print STDERR "Shutdown requested.  Leaving sweep loop.\n";
      last;
    }

    # Fractional throttle.
    select (undef, undef, undef, $throttle);
}

print STDERR "End of Program.  Closing DB connection\n";

# Clean up.
$sth->finish();
$dbh->disconnect();

