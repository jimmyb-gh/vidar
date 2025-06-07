#!/bin/sh
#
# vidar_start.sh  - start vidar.
#    Also load rules to allow ip, ipv6, icmp, icmp6 from any to any
#    and runs necessary scripts.
#    Must be root to run this script.

echo
echo "========  VIDAR: vidar_start.sh  ========="
echo

usage()
{
  echo
  echo "usage: vidar_start.sh  - starts Vidar."
  echo "       Also loads rules '650** allow ip from any to any',"
  echo "       starts the sec_start.sh script, and starts the"
  echo "       vidar_add2BAD.sh script sending output to BAD.out"
  echo "       in the configured logs directory."
  echo "  Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}

# Pick up environment for this run, and print it out.
. ../vidar_env.sh 


ME=`id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi


# Remove all logs first.  Safely.
OLDLOGS=""

echo
echo "Removing old logs first..."


if [ -z "${VIDAR_LOGS}" ]
then # The VIDAR_LOGS variable is NOT SET. Bail out.
  echo "The VIDAR_LOGS variable [${VIDAR_LOGS}] is NOT SET. Bailling out."
  usage;
else
  for i in "${VIDAR_LOGS}"/*
  do
    if [ -f "${i}" ]
    then
#      echo "Adding ${i} to OLDLOGS"
      OLDLOGS="${OLDLOGS} ${i}"
    fi
  done
fi

if [ ! -z "${OLDLOGS}" ]
then 
  echo "OLDLOGS=[${OLDLOGS}]"
  echo
  echo "USING rm -i ${OLDLOGS}"
  echo
  echo "Remove them all by 'y' and return, or not by hitting 'n' and return."
  echo
  rm -i ${OLDLOGS}
else
  echo "No logs to delete."
fi



# IPFW setup commands.  This script does NOT kldload ipfw.
# Set up logging to /var/log/security and enable logging on rule 65000.
# Use a here document to execute them in order.

#sysctl net.inet.ip.fw.verbose=1

# Create a file of ipfw commands.

echo "kldunload ipfw"                                             >  /tmp/cmds.$$
echo "kldload ipfw"                                               >> /tmp/cmds.$$
echo "ipfw add 65000 allow ip from any to any"                    >> /tmp/cmds.$$
echo "ipfw add 65005 allow ipv6 from any to any"                  >> /tmp/cmds.$$
echo "ipfw add 65010 allow icmp from any to any"                  >> /tmp/cmds.$$
echo "ipfw add 65015 allow icmp6 from any to any"                 >> /tmp/cmds.$$
echo "ipfw add 65020 allow tcp from any to any established"       >> /tmp/cmds.$$
echo "ipfw table BAD create type addr missing"                    >> /tmp/cmds.$$
echo "ipfw add 60000 deny ip from table\\\\(BAD\\\\) to any"      >> /tmp/cmds.$$
echo "ipfw table BAD add 9999:9999:9999:9999:9999:9999:9999:9999" >> /tmp/cmds.$$
echo "ipfw table BAD list"                                        >> /tmp/cmds.$$
echo "ipfw list"                                                  >> /tmp/cmds.$$

echo -n "Loading Vidar... "


# Read and execute the commands one at a time (not in a subshell).
while IFS= read CMD
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
    rm -f /tmp/cmds.$$
    echo "  Exiting..."
    exit 1
  fi
  echo
done < /tmp/cmds.$$

rm -f /tmp/cmds.$$


# Start Sec.  The UDP port assignment and LOGS assignment are
# set by the "fixup_rules.sh" script in the ${VIDAR_SEC} directory.
# That script must be run every time you restart Vidar.  
#

#set -x
#${VIDAR_SCRIPTS}/sec_start.sh  | ${VIDAR_SCRIPTS}/vidar_add2BAD.sh > ${VIDAR_LOGS}/add2BAD.out 2>&1 & 
#${VIDAR_SCRIPTS}/sec_start.sh  


cd ${VIDAR_SEC}

# Fix rulesets.
${VIDAR_SEC}/fixup_rules.sh

# Let 'er rip...
${VIDAR_SCRIPTS}/sec_start.sh 2>/dev/null  | ${VIDAR_SCRIPTS}/vidar_add2BAD.sh  

# Script does not exit until killed.
exit 0

