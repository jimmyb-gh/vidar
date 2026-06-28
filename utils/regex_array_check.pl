#!/usr/local/bin/perl

# read input and match against regular expression array

use strict;
use warnings;

my @reArr = (
'Connection closed by invalid user (\w+) (.*?) port (\d+) \[preauth\]',
'reverse mapping checking getaddrinfo for (.*?) \[(.*?)\] failed\.',
'reverse mapping checking getaddrinfo for (.*?) \[(.*?)\] failed\.',
'banner exchange\: Connection from (.*?) port (.*?)\: invalid format',
'Invalid user (.*?) from (.*?) port (\d*)',
'Address (.*?) maps to (.*?), but this does not map back to the address\.',
'Invalid user (.*?) from (.*?) port (\d*)',
);



while(<>) {
    my $inputline = $_;
    my $found = 0;
    chop $inputline;

    for my $aref (@reArr) {
        if ( $inputline =~ /$aref/ ) {
            print "MATCHED!\n";
            print "[$inputline]\n";
            print "one   = [$1]\n";
            print "two   = [$2]\n";
            $found = 1;
        } else {
            ;
        }
    }
    print "no match on [$inputline]\n" if $found == 0;
}

#Connection closed by 2a06:4883:9000::9e port 52611 [preauth]
#Connection closed by 185.247.137.179 port 36491 [preauth]
#'Connection closed by (.*?) port (\d+) \[preauth\]'
#
#reverse mapping checking getaddrinfo for scanner-203.hk2.censys-scanner.com [199.45.154.132] failed.
#'reverse mapping checking getaddrinfo for (.*?) \[(.*?)\] failed\.'

#reverse mapping checking getaddrinfo for unused-space.coop.net [2a06:4883:9000::9e] failed.
#'reverse mapping checking getaddrinfo for (.*?) \[(.*?)\] failed\.'

#banner exchange: Connection from 206.168.34.35 port 44458: invalid format
#banner exchange: Connection from 2a06:4883:9000::9e port 17645: invalid format
#'banner exchange\: Connection from (.*?) port (.*?)\: invalid format'
#'Invalid user (.*?) from (.*?) port (\d*)'

#Address 179.43.144.242 maps to hostedby.privatelayer.com, but this does not map back to the address.
#Address 2a05:2342:9000:99 maps to hostedby.privatelayer.com, but this does not map back to the address.
#'Address (.*?) maps to (.*?), but this does not map back to the address\.'

#Invalid user linuxserver from 125.67.215.189 port 39617
#Invalid user linuxserver from IPV6 ADDRESS HERE port 39617
#Invalid user tr\\bv from 125.67.215.189 port 44513
#'Invalid user (.*?) from (.*?) port (\d*)'
#
