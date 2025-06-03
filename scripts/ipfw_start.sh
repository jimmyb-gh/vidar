#!/bin/sh
#
# ipfw_start.sh  - start the firewall by loading ipfw.ko
#    Also load rule 65000 allow ip from any to any
#    Must be root to run this script.

usage()
{
  echo
  echo "usage: ipfw_start.sh  - start the firewall by loading ipfw.ko"
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

# IPFW setup commands.
# Use a here document to execute them in order.

COMMANDS=$(cat <<EOF
kldload ipfw
ipfw add 65000 allow ip from any to any
ipfw table BAD create type addr missing
ipfw add 60000 deny ip from table\\\(BAD\\\) to any
ipfw table BAD add 9999:9999:9999:9999:9999:9999:9999:9999
ipfw table BAD list
ipfw list
EOF
)

echo -n "Loading IPFW... "


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

