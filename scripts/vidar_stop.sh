#!/bin/sh
#
#  vidar_stop.sh  - stop the firewall by unloading ipfw.ko
#    Must be root to run this script.

usage()
{
  echo
  echo "usage: vidar_stop.sh  - Stop the Vidar pipeline."
  echo "                        Leave IPFW alone."
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

# Pick up environment for this run.

SHOW_ENV="Y"
. ../vidar_env.sh



echo "Killing Vidar pipeline by killing Sec."

echo "kill -TERM \`cat ${VIDAR_PIDS}/sec.pid\`"
kill -TERM `cat ${VIDAR_PIDS}/sec.pid`
echo
#echo "Killing vidar_add2BAD.sh too, just for good measure."
# Kill vidar_add2BAD.sh too, just in case it's throwing errors.
#kill -TERM `cat ${VIDAR_PIDS}/add2BAD.pid`

echo "Last 3 lines of ${VIDAR_LOGS}/sec.out"

if [ -f ${VIDAR_LOGS}/sec.out ]
then
    tail -3 ${VIDAR_LOGS}/sec.out
fi

echo -n "Stopping and unloading ipfw... "

STATUS=`/sbin/kldunload ipfw`

if [ $? -ne 0 ]
then
  echo
  echo "Error on unloading ipfw. Return code [${STATUS}]"
  echo "  Check ipfw module, and unload manually with 'kldunload ipfw'"
  exit 2
else
  echo "Done. ipfw kernel module unloaded."
  # show proof here.
  echo
fi

echo "VIDAR is stopped."

echo

exit 0


