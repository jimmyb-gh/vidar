#!/usr/bin/env perl
use strict;
use warnings;
use DBI;

# vidar_connectiontest.pl - check vidar connection to PostgreSQL vidar database.
#
# Note, the production version uses peer authentication.
# Ensure that pg_hba.conf is set up for peer authentication for user vidar.
#
# To use this test, become user vidar and source the environment at
# /home/vidar/src/vidar/etc/vidar_env.sh for development or
# /usr/local/vidar/etc/vidiar_env.sh for production.
# Then run perl vidar_connectiontest.pl
# 

my $vidar_home = $ENV{VIDAR_HOME};

print "NOTE: Checking environment:vidar_home = [$vidar_home]\n";


# Prepare connection to database.
#my $dbh = DBI->connect(
#    "dbi:Pg:dbname=vidar",
#    "jpb",  # adjust username
#    "semajj123",          # adjust password
#    { AutoCommit => 1, RaiseError => 1 }
#) or die "Can't connect: $DBI::errstr";




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

print "DBI->connect() for user vidar using peer authentication succeeded!\n";
exit;




