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

#$dbh->{FetchHashKeyName} = 'NAME_lc';

# Prepared statement for ipfw_queue table.
# Look for entries that have aged out.
my $sth = $dbh->prepare(
    "select * from ipfw_queue where remove_after <  now() - interval '5 minutes' order by remove_after desc"
);


# Execute
eval {
    $sth->execute();
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
    print STDERR "[ip_addr is $hash_ref->{'ip_addr'}\tblocktime is $hash_ref->{'blocktime'}]\n";

#    # Send validated IP to add2BAD.pl script.
#    print STDOUT "$ip\n";
}


print STDERR "End of Program.  Closing DB connection\n";

$sth->finish();
$dbh->disconnect();
