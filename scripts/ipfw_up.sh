#!/bin/sh
set -x

# Starting IPFW while logged in requires special handling.
# Use kenv(1) to setup the following sysctls *before* 
# loading the ipfw kernel module:
#
# To do this effectively, use daemon(8) as follows:
#
# /usr/sbin/daemon -f /bin/sh -c 'sleep 10; /root/src/vidar/scripts/ipfw_up.sh'
#
# Note that this script is called from /root/src/vidar/scripts/vidar_start_postgres.sh
# which uses daemon to call this script.  Only use the above command if running this
# script directly (for testing).

#

# sleep for 5 seconds first

sleep 5

# Start with ipfw disabled.
kenv "net.inet.ip.fw.enable=0"

# Start with default to deny (which is the default anyway)
kenv "net.inet.ip.fw.default_to_accept=0"

# Now load IPFW and apply our tables and rules.
kldload ipfw

# GOOD table 
ipfw table GOOD create type addr missing
# OCH
#ipfw table GOOD add 2600:1700:3901:4940:3e97:eff:fe10:92f2
#ipfw table GOOD add 108.253.226.42

# Lab testing
ipfw table GOOD add 203.0.113.10

# Gregory 
ipfw table GOOD add 68.34.27.251
ipfw table GOOD add 2601:410:8601:3af0:3e97:eff:fe10:92f2
ipfw table GOOD list

# GOOD table rules for good people.
ipfw add 59950 allow ip from table\(GOOD\) to any
ipfw add 59955 allow ip6 from table\(GOOD\) to any
ipfw add 59960 allow icmp from table\(GOOD\) to any
ipfw add 59965 allow ipv6-icmp from table\(GOOD\) to any

# Operate open, until fuckery happens.
ipfw add 65000 allow ip from any to any
ipfw add 65005 allow ipv6 from any to any
ipfw add 65010 allow icmp from any to any
ipfw add 65015 allow icmp6 from any to any
ipfw add 65020 allow tcp from any to any established

#
# Set up for BAD and add a bogon.
ipfw table BAD create type addr missing
ipfw table BAD add 9999:9999:9999:9999:9999:9999:9999:9999
ipfw table BAD list

# Note the rule number below. 
# Put the BAD table after the GOOD table, but *before* open operation at 65000
ipfw add 60000 deny ip from table\(BAD\) to any
ipfw list

echo "Enabling IPFW."
ipfw enable firewall


# Should now be secure with GOOD table and BAD tables and open operation
# for anyone who hasn't fucked with us.

exit

