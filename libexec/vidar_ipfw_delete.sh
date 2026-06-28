#!/bin/sh

# vidar_ipfw_delete.sh
#
# usage:  vidar_ipfw_delete.sh  <IPaddress>
#
# IPaddress can be either IPv4 or IPv6  as long as it is a valid address.
# This script reads the entry from the command line and deletes it from
# IPFW.
#
# This script must be run as root.  The strategy is to put this one
# script in /usr/local/etc/sudoers.d/vidar as the only script
# user vidar can run as sudo.


IP="$1"

case "$IP" in

  *[!0-9a-fA-F:.]* | "")
    echo "Invalid IP passed to vidar_ipfw_delete.sh" >&2
    exit 1
  ;;
esac

/sbin/ipfw table BAD delete "$IP"



