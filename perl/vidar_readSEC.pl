#!/usr/bin/env perl
use strict;
use warnings;
use DBI;
use Time::Piece;
use Time::Seconds;

#
# vidar_readSEC.pl - read SEC pipe-delimited output and update the
#                    PostgreSQL database.
#

# Subroutine to compute the remove_after time to insert into PostgreSQL.
# If there is a problem with the incoming ofense_time variable,
# set the return time to now + 4 hour (using perl's time function).
sub compute_remove_after {
    my ($offense_time, $block_seconds) = @_;

    warn "missing offense_time\n"  unless defined $offense_time;
    warn "missing block_seconds\n" unless defined $block_seconds;
    warn "invalid block_seconds\n" unless $block_seconds =~ /^\d+$/;

    if($offense_time =~ /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/) {
      my $t = Time::Piece->strptime($offense_time, "%Y-%m-%d %H:%M:%S");
      my $remove_after = $t + $block_seconds;
      return $remove_after->strftime("%Y-%m-%d %H:%M:%S");
    }
    else {
      my $remove_after = Time::Piece->new(time + 14400); # add 4 hours to current time
      return $remove_after->strftime("%Y-%m-%d %H:%M:%S");
    }

}

#
# Sat Jun  6 20:59:40 EDT 2026
# Note: Now using just single table model for PostgreSQL DB.
#       The execute statement for insert uses the "UPSERT" version
#       and updates only the repeat_count if the offender_ip already exists.
#
# The caller should source the vidar environment at
#  /usr/local/vidar/etc/vidar_env.sh
#


print  STDERR "Start of Program\n" ;

my $vidar_home = $ENV{VIDAR_HOME};

print STDERR "vidar_home = [${vidar_home}]\n";

exit if $vidar_home eq "";

print  STDERR "Setting up DB connection\n" ;

# set for unbuffered output
$| = 1;

# Prepare connection to database.
#
# Now using the peer authorization method.  (See vidar_connectiontest.pl)
# Peer authentication requires an update to pg_hba.conf (see example at
# ~/src/vidar/postgres/vidar.sql.

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

print STDERR  "DBI->connect() succeeded!\n";

# NOTES: The UPSERT clause in this SQL statement is complex.
# It has to account for the situation where, after a permenent_blocked
# offender_ip record is in the database and a second offense comes from the
# same offender_ip (likely in the same SMTP session) which has lower
# risk, the second event MUST NOT overwrite the block_seconds and
# permanent_block fields of the first record.
# The various UPSERT clauses below account for that possibility.


# Prepared statement for offenders table using perl quoting.
my $offenders_sth = $dbh->prepare(q{
     INSERT INTO offenders (offense_time,
                            offender_ip,
                            desc_line,
                            entry,
                            context,
                            rule_num,
                            permanent_block,
                            block_seconds,
                            active_block,
                            remove_after,
                            ipfw_removed_at,
                            repeat_count,
                            evidence) 
     VALUES (?,
             ?::inet,
             ?,
             ?,
             ?,
             ?,
             ?,
             ?,
             ?,
             ?,
             ?,
             ?,
             ?)
     ON CONFLICT (offender_ip)
     DO UPDATE
     SET
         offense_time    = EXCLUDED.offense_time,
         desc_line       = EXCLUDED.desc_line,
         entry           = EXCLUDED.entry,
         context         = EXCLUDED.context,
         rule_num        = EXCLUDED.rule_num,
         repeat_count    = offenders.repeat_count + 1,
         /*
         * A permanent block can be added, but it can never be
         * downgraded by a later temporary-blocked event.
         */
         permanent_block = GREATEST(
             offenders.permanent_block,
             EXCLUDED.permanent_block
         ),
         /*
         * Preserve the existing permanent_block value of block_seconds.
         * If neither event is permanent, retain the longer
         * block_seconds duration so a lower risk (weaker) event cannot
         * shorten an existing block_seconds value.
         *
         * Also, use multiplier from function vidar_blocking_multiplier
         * to adjust the block time for repeat offenders.
         * See postgres/vidar.sql for more info.
         */
         block_seconds   = CASE
             WHEN offenders.permanent_block = 1
               OR EXCLUDED.permanent_block = 1
                 THEN 0
             ELSE GREATEST(
         /*
         * Notice the extra bind parameter ('?') here.  It is bound to an extra $block_seconds
         * during the execute statement below.  We need the original block_seconds from
         * the SEC rule for the calculation in the vidar_blocking_multiplier function.
         * The rule is "never decrease a block_seconds value." It should be monotonically increasing only.
         */
                 round(
                  ? *  vidar_blocking_multiplier(offenders.repeat_count + 1)),
                 EXCLUDED.block_seconds,
                 offenders.block_seconds
                 )
             END,
         /*
         * A permanent_blocked record removal time is irrelevant to
         * the vidar_sweepIPFW.pl sweeper program, but we preserve it
         * rather then replacing it with the newer event's removal time.
         * For temporary blocks, retain the later expiration.
         * The value 'inifinity'::timestamp is considered never removed.
         */
         remove_after    = CASE
             WHEN offenders.permanent_block = 1
               OR EXCLUDED.permanent_block = 1
                 THEN 'infinity'::timestamp
             ELSE GREATEST(
                 offenders.remove_after,
                 EXCLUDED.remove_after
                 )
             END,
         /*
         * Always ensure the address is active in IPFW.
         * Also, clear the ipfw_remove_after.
         * See the constraint on this field.
         */
         active_block    = 1,
         ipfw_removed_at = NULL,
         evidence        = LEFT (
                              EXCLUDED.evidence
                              || E'\n--- previous evidence ---\n'
                              || offenders.evidence,
                              50000
                           )
     });


print  STDERR "Ready for input\n" ;

while (<STDIN>) {
    my $inputline = $_;
    chomp;
    next if /^\s*$/;

# DEBUGGING
    print STDERR "[$inputline]\n";
    
    # $block_seconds is an integer number of seconds to block the IP.
    # Each sec rule has it's own block_seconds value or 0 (permanent block).

    # Each sec write action outputs a line in this format.
    my ($time, $ip, $desc, $entry, $context, $rule, $block_seconds, $evidence) = split /\|/, $_, 8;
    my $repeat_count = 1; # the default

    my $active_block = 1;
    my $ipfw_removed_at = undef; #undef is correct for a NULL value in DBI

    # Sanitize inputs
    unless (defined $time && $time =~ /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}$/) {
        warn "Invalid timestamp format: [$time]\n";
        next;
    }
    
    unless (defined $ip && $ip =~ /^[\d\.:a-fA-F]+$/) {
        warn "Invalid IP format: [$ip]\n";
        next;
    }
    
    unless (defined $rule && $rule =~ /^\d+$/) {
        warn "Invalid rule number: [$rule]\n";
        next;
    }
    
    unless (defined $block_seconds && $block_seconds =~ /^\d+$/) {
        warn "Invalid block_seconds: [$block_seconds]\n";
        next;
    }
    
    unless (defined $context && length($context) <= 20) {
        warn "Invalid context: [$context]\n";
        next;
    }
    
    # logs can be anything - no shell execution risk in INSERT
    
# DEBUGGING ONLY
    print STDERR "Inserting record into offenders table for rule [$rule]\n";

    # Note that $block_seconds is actually a flag value:
    # if it is zero, it's a permanent block, if any other value it is not.
    # Therefore, the conditional below checks the flag value and assigns
    # 1 (true) if the incoming value is zero, or 0 (false) if not
    # to $permanent_block.
    # The values are set in every SEC rule write line.

    my $permanent_block = ($block_seconds == 0) ? 1 : 0;

    # my $remove_after = compute_remove_after($time, $block_seconds);
    my $remove_after = $permanent_block == 1 ? 'infinity'
        : compute_remove_after($time, $block_seconds);

    eval {
        $offenders_sth->execute($time,
                                $ip,
                                $desc,
                                $entry,
                                $context,
                                $rule,
                                $permanent_block,
                                $block_seconds,
                                $active_block,
                                $remove_after,
                                $ipfw_removed_at,
                                $repeat_count,
                                $evidence,
                                $block_seconds);  # Extra bind value. See note in UPSERT clause above.
    };
    if ($@) {
        warn "Insert into offenders failed: $@";
        next;
    }


    # Send validated IP to add2BAD.pl script along with the permanent_block status.
    print STDOUT "$ip|$permanent_block\n";
}


print STDERR "End of Program.  Closing DB connection\n";

$offenders_sth->finish();
$dbh->disconnect();
