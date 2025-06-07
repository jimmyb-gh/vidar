#!/bin/sh
#
#  vidar_stop.sh  - stop the firewall by unloading ipfw.ko
#    Must be root to run this script.

usage()
{
  echo
  echo "usage: vidar_stop.sh  - stop the firewall by unloading ipfw.ko"
  echo
  echo "  Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}

ME=`/usr/bin/id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi

# Pick up environment for this run, but don't print it out.
. ../vidar_env.sh Q


echo -n "Stopping and unloading ipfw... "

STATUS=`/sbin/kldunload ipfw`

if [ $? -ne 0 ]
then
  echo
  echo "Error on unloading ipfw. Return code [${STATUS}]"
  echo "  Check ipfw module, and try again."
  exit 2
else
  echo "done. ipfw kernel module unloaded."
  # show proof here.
  echo
fi

exit 0


