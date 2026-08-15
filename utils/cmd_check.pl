#!/usr/local/bin/perl
#
# cmd_check.pl - check the current process list against list of suspicious activity.
#


use strict;
use warnings;

my $testpattern = '^(at|bash|cat|cc|curl|ee|fetch|ftp|less|more|nc|ncat|perl|ping|pkg|ps|pyth|rsync|scp|sftp|sh|ssh|sshd\-session|vi|wget)\s*$';


my @procs = `ps -acxo '%cpu,start,ruser,uid,tt,pid,ppid,state,command'`;

# print "[$procs[5]]\n";


my $inputline = "";

my $cmdline = "";


foreach $cmdline (@procs)
{
  chomp $cmdline;

  my($cpct,$start,$ruser,$uid,$tt,$pid,$ppid,$state,$command) = split(" ",$cmdline);

  # print "[$cpct][$start][$ruser][$uid][$tt][$pid][$ppid][$state][$command]\n";


  if ( $command =~ /$testpattern/i ) {
      print "MATCHED!\n";
      print "one   = [$1]\n";
  } else {
#      print "no match.\n";
    ;

  }
}
