#!/bin/sh
#
# ipfw_start.sh  - start vidar.
#    Also load rules to allow ip, ipv6, icmp, icmp6 from any to any
#    Must be root to run this script.

usage()
{
  echo
  echo "usage: ipfw_start.sh  - start vidar. Do not load/unload ipfw.ko."
  echo "       Also load rule 65000 allow ip from any to any."
  echo
  echo "  Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}

ME=`id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi

#set -x

# IPFW setup commands.  This script does NOT kldload ipfw.
# Set up logging to /var/log/security and enable logging on rule 65000.
# Use a here document to execute them in order.

COMMANDS=$(cat <<EOF
sysctl net.inet.ip.fw.verbose=1
ipfw add 65000 allow log ip from any to any
ipfw add 65005 allow log ipv6 from any to any
ipfw add 65010 allow log icmp from any to any
ipfw add 65015 allow log icmp6 from any to any
ipfw add 65020 allow tcp from any to any established
ipfw table BAD create type addr missing
ipfw add 60000 deny ip from table\\\(BAD\\\) to any
ipfw table BAD add 9999:9999:9999:9999:9999:9999:9999:9999
ipfw table BAD list
ipfw list
EOF
)

echo -n "Loading vidar... "


echo "$COMMANDS" | while IFS= read CMD
do
  echo "Running: [${CMD}]"
  sh -c "${CMD}"
  RV=$?
  if [ ${RV} -ne 0 ]
  then
    echo
    echo "Error on running command [${CMD}]. Return code [${RV}]"
    echo "  Unloading ipfw.  Check and try again."
    kldunload ipfw
    echo "  Exiting..."
    exit 1
  fi
  echo
done

exit 0

