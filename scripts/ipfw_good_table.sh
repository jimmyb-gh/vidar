#!/bin/sh

# GOOD table
ipfw table GOOD create type addr missing
# OCH
#ipfw table GOOD add 2600:1700:3901:4940:3e97:eff:fe10:92f2
#ipfw table GOOD add 108.253.226.42

# Gregory
ipfw table GOOD add 68.34.27.251
ipfw table GOOD add 2601:410:8601:3af0:3e97:eff:fe10:92f2
ipfw table GOOD list

# GOOD table rules
ipfw add 59950 allow ip from table\(GOOD\) to any
ipfw add 59955 allow ip6 from table\(GOOD\) to any
ipfw add 59960 allow icmp from table\(GOOD\) to any
ipfw add 59965 allow ipv6-icmp from table\(GOOD\) to any

