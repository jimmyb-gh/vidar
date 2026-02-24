#!/bin/sh
#
# vidar_start_postgres.sh  - start vidar.
#    Also load rules to allow ip, ipv6, icmp, icmp6 from any to any
#    and runs necessary scripts.
#    Must be root to run this script.


usage()
{
  echo
  echo "usage: vidar_start.sh  - starts Vidar."
  echo "       Also loads IPFW rules '650** allow ip from any to any',"
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
# "input" here is local input for ps.txt, net4.txt, and net6.txt
# 

for i in logs pids scripts sec utils input
do
  echo "Checking directories: [${VIDAR_HOME}/${i}]"
  mkdir -p ${VIDAR_HOME}/${i}
done


# Remove old PID files.

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

#rm /root/src/vidar/logs/*


# Remove all logs.
OLDLOGS=""

echo "Removing old logs ...."

if [ -z "${VIDAR_LOGS}" ]
then # The VIDAR_LOGS variable is NOT SET. Bail out.
    echo "The VIDAR_LOGS variable [${VIDAR_LOGS}] is NOT SET. Bailling out."
    usage;
else
    for i in "${VIDAR_LOGS}"/*
    do
#        echo "[filename: ${i}]"
        # Skip the symbolic link "BAD.txt".
        if [ -L "${i}" ]
        then
            echo "Skipping symbolic link: [${i}]"
        else
            if [ -f "${i}" ]
            then
#                echo "Adding ${i} to OLDLOGS"
                OLDLOGS="${OLDLOGS} ${i}"
            fi
        fi
    done
fi

if [ ! -z "${OLDLOGS}" ]
then 
    echo "OLDLOGS=[${OLDLOGS}]"
    echo
    echo "USING rm  ${OLDLOGS}"
    rm  ${OLDLOGS}
else
    echo "No logs to delete."
fi

echo "Unloading IPFW if necessary..."

kldstat | grep ipfw > /dev/null 2>&1
IPFWSTAT=$?

if [ ${IPFWSTAT} -eq 0 ]  # ipfw is loaded
then
    kldunload ipfw
fi

# Let settle.
sleep 1

cd ${VIDAR_SCRIPTS}

chmod +x ipfw_up.sh

# This script creates both GOOD and BAD tables and sets
# up the necessary rules.
#
# Must use daemon(8) to start ipfw.  There is a short delay. See the notes in ipfw_up.sh.

/usr/sbin/daemon -f /bin/sh -c 'sleep 5; /root/src/vidar/scripts/ipfw_up.sh'

# Check status
while :
do
  kldstat | grep ipfw > /dev/null 2>&1
  RV=$?
  if [ ${RV} -ne 0 ]  # ipfw not loaded yet.  sleep it off.
  then
    sleep 10
    echo
    echo "Waiting for ipfw to load, return code [${RV}]"
    echo "  sleeping for 5 seconds"
  else
    break
  fi
done

sleep 2

echo "IPFW loaded.  Starting SEC..."

#
# Start Sec.  The LOGS assignment is set by the "fixup_rules.sh"
# script in the ${VIDAR_SEC} directory.
# That script must be run every time you restart Vidar.  
#

cd ${VIDAR_SEC}

# Fix rule sets.
echo "Fixing rulesets..."
${VIDAR_SEC}/fixup_rules.sh

# Sec is the key process in the below pipeline.
# Sending a TERM signal to the Sec process will stop the whole enchilada.

# Let 'er rip. The outer braces group the processes together and the ampersand
# ensures they run in the background.
# sec_start.sh starts SEC to process logfiles and output all data.
# vidar_readSEC.pl reads the entire output of SEC, updates the vidar postgres
# database and outputs just the IP address.
# vidar_add2BAD.pl reads the incoming IP address and updates the BAD table in IPFW.
# Note that the GOOD and BAD tables are already set up by ipfw_p.sh.

# For debugging, both postgres/vidar_readSEC.pl and postgres/vidar_add2BAD.pl write to stderr
# which can be redirected to (for example) /tmp/readSEC_stderr.txt and /tmp/add2BAD_stderr.txt
{
   exec   ${VIDAR_SCRIPTS}/sec_start.sh 2>${VIDAR_SEC_STDERR} \
        | sudo perl /root/src/vidar/postgres/vidar_readSEC.pl  2>${VIDAR_READSEC_STDERR} \
        | sudo perl /root/src/vidar/postgres/vidar_add2BAD.pl  2>${VIDAR_ADD2BAD_STDERR}
} &

echo "Waiting for Sec startup."
sleep 3
# Script waits here. Above pipeline continues. Kill with vidar_stop.sh
# Technical notes:
# Sec ignores SIGPIPE from add2BAD closing stdout.
# It will keep running, but throw error messages.
# Also, Sec handles SIGINT for adjusting debug output,
# so SIGINT can't be used to kill the pipeline.
# To kill the Vidar pipeline, send SIGTERM, not SIGINT, to Sec pid.
#
echo
echo "Vidar pipeline started."
echo "Sleeping 3 seconds to let Sec settle..."
sleep 3
echo "Use Sec pid to kill Vidar pipeline."
echo "Kill with -TERM to Sec pid [`cat ${VIDAR_PIDS}/sec.pid`]"

exit 0


