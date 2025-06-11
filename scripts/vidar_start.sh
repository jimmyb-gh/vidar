#!/bin/sh
#
# vidar_start.sh  - start vidar.
#    Also load rules to allow ip, ipv6, icmp, icmp6 from any to any
#    and runs necessary scripts.
#    Must be root to run this script.


usage()
{
  echo
  echo "usage: vidar_start.sh  - starts Vidar."
  echo "       Also loads rules '650** allow ip from any to any',"
  echo "       starts the sec_start.sh script, and starts the"
  echo "       vidar_add2BAD.sh script sending output to BAD.out"
  echo "       in the configured logs directory."
  echo
  echo "  Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}

# Pick up environment for this run, and print it out.

cd /root/src/vidar/scripts

SHOW_ENV="Y"
. ../vidar_env.sh


ME=`id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi

#
# Ensure we have all the directories we need.
#

for i in logs pids scripts sec utils
do
  echo "Checking directories: [${VIDAR_HOME}/${i}]"
  mkdir -p ${VIDAR_HOME}/${i}
done


# Remove old PID files.  Safely.

echo "Checking old pid files..."

for i in `ls ${VIDAR_PIDS}`
do
    echo "pid file  = [${i}]"
    PIDFILE=${VIDAR_PIDS}/${i}
    echo -n "Found old pid file [${PIDFILE}] with pid: "
    APID=`cat ${PIDFILE}` && echo ${APID}
    # Check here if pid is real, and pid exists.
    if [ "X${APID} != "X} ]
    then
        ps -xp ${APID}
        if [ $? -ne 0 ]
        then # pid does not exist
            echo "Stale pid file with no active process.  Deleting file."
            echo "rm ${PIDFILE}"
            rm ${PIDFILE}
            echo
            continue
        else # pid does exist
            read -p "Should this PID be killed? (y/n):" KILLPID
            if [ "X${KILLPID}" = "Xy" -o "X${KILLPID}" = "XY" ]
            then
                echo "Killing PID [${APID}]"
                echo "kill -TERM ${APID}"
                kill -TERM ${APID}
                rm ${PIDFILE}
                echo
            fi
        fi
        echo
    fi
done

# On boot, remove all old logs.
# This path is HARDCODED for safety.

rm /root/src/vidar/logs/*


# Remove all logs.  Safely.
OLDLOGS=""

echo "Removing old logs ...."

if [ -z "${VIDAR_LOGS}" ]
then # The VIDAR_LOGS variable is NOT SET. Bail out.
    echo "The VIDAR_LOGS variable [${VIDAR_LOGS}] is NOT SET. Bailling out."
    usage;
else
    for i in "${VIDAR_LOGS}"/*
    do
        if [ -f "${i}" ]
        then
#          echo "Adding ${i} to OLDLOGS"
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
    echo "Remove each one  by 'y' and return, or not by hitting 'n' and return."
    echo
    rm -i ${OLDLOGS}
else
    echo "No logs to delete."
fi

echo "Unloading IPFW if necessary..."

kldstat | grep ipfw > /dev/null 2>&1
IPFWSTAT=$?

if [ ${IPFWSTAT} -eq 0 ]
then
    kldunload ipfw
fi

# Let settle.
sleep .5

# IPFW setup commands.  This script (re)loads ipfw.
# Create a file of ipfw commands.

echo "Loading IPFW... "

echo "kldload ipfw"                                                > /tmp/cmds.$$
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

echo  "Loading Vidar... "


# Read and execute the above commands one at a time (not in a subshell).
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
done < /tmp/cmds.$$

rm -f /tmp/cmds.$$

#
# Start Sec.  The LOGS assignment is set by the "fixup_rules.sh"
# script in the ${VIDAR_SEC} directory.
# That script must be run every time you restart Vidar.  
#

cd ${VIDAR_SEC}

# Fix rule sets.
${VIDAR_SEC}/fixup_rules.sh

# Sec is the key process in the below pipeline.
# Sending an TERM signal to the Sec process will stop the whole enchilada.

# Let 'er rip.
{
   exec   ${VIDAR_SCRIPTS}/sec_start.sh 2>/dev/null \
        | ${VIDAR_SCRIPTS}/vidar_add2BAD.sh >${VIDAR_LOGS}/vidar_add2BAD.txt 
} &

echo "Waiting for Sec startup."
sleep 5
# Script waits here. Above pipeline continues. Kill with vidar_stop.sh
# Technical notes:
# Sec ignores SIGPIPE from add2BAD closing stdout.
# It will keep running, but throw error messages.
# Also, Sec handles SIGINT for adjusting debug output,
# so SIGINT can't be used to kill the pipeline.
# To kill the Vidar pipeline, send SIGTERM, not SIGINT, to Sec pid.
#
echo "Vidar pipeline started."
echo "Use Sec pid to kill Vidar pipeline."
echo "Kill with -TERM to Sec pid [`cat ${VIDAR_PIDS}/sec.pid`]"

exit 0


