#!/bin/sh
set -x
kldload ipfw
ipfw add 65000 allow ip from any to any
ipfw add 65005 allow ipv6 from any to any
ipfw add 65010 allow icmp from any to any
ipfw add 65015 allow icmp6 from any to any
ipfw add 65020 allow tcp from any to any established
ipfw table BAD create type addr missing
ipfw add 60000 deny ip from table\(BAD\) to any
ipfw table BAD add 9999:9999:9999:9999:9999:9999:9999:9999
ipfw table BAD list
ipfw list
exit

