#!/usr/local/bin/perl
#
# cmd_check.pl - check the current process list against list of suspicious activity.
#


use strict;
use warnings;

my $testpattern = '^(at|bash|cat|cc|curl|ee|fetch|ftp|less|more|nc|ncat|perl|ping|pkg|ps|pyth|rsync|scp|sftp|sh|ssh|sshd\-session|vi|wget)\s*$';


my @procs = `/bin/ps -acxo '%cpu,start,ruser,uid,tt,pid,ppid,state,command'`;

# print "[$procs[5]]\n";


my $inputline = "";

my $line = "";

my $matched = 0;

foreach $line (@procs)
{
  chomp $line;

  my($cpct,$start,$ruser,$uid,$tt,$pid,$ppid,$state,$command) = split(" ",$line);

  # print "[$cpct][$start][$ruser][$uid][$tt][$pid][$ppid][$state][$command]\n";


  if ( $command =~ /$testpattern/i ) {
      print "MATCHED!\n";
      print "one   = [$1]\n";
      $matched = 1;
  } else {
#      print "no match.\n";
    ;

  }
}

if ($matched == 1) {
  @procs = `/usr/bin/w  -n`;

  foreach $line (@procs)
  {
    chomp $line;

    print "$line\n";
  }
}


