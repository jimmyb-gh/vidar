#!/bin/sh
#
#  push.sh  - push data into auth.log, maillog, and access.log

# Pick up the environment

usage(){
  echo
  echo "Usage: push.sh throttle - decimal number (e.g. 0.5, 1, 0.005, etc.)"
  echo "                          to use as the throttle for allowing data through."
  echo "                          Thottle is wait time between passing lines."
  echo 
  exit 1
}

# Store  pids of child processes.
PIDS=""

# Cleanup before exiting
cleanup() {
  echo "Caught interrupt.  Killing all child processes..."
  for pid in ${PIDS}
  do
    echo "killing $pid"
    kill "$pid" 2>/dev/null
  done
  exit 1
}

trap cleanup INT TERM 

if [ $# -ne 1 ]
then
  usage;
else
  THROTTLE=$1
fi

echo "Throttle is [${THROTTLE}]"


# Pick up the environment

export SHOW_ENV="Y"
. ~/src/vidar/vidar_env.sh

# Touch all the output files:
touch ${VIDAR_LOGS}/ALLOW.TXT
touch ${VIDAR_LOGS}/BLOCKED_AUTH.TXT
touch ${VIDAR_LOGS}/BLOCKED_EMAIL.TXT
touch ${VIDAR_LOGS}/BLOCKED_NGINX.TXT
touch ${VIDAR_LOGS}/NOT_MATCHED_AUTH.TXT
touch ${VIDAR_LOGS}/NOT_MATCHED_EMAIL.TXT
touch ${VIDAR_LOGS}/NOT_MATCHED_NGINX.TXT
touch ${VIDAR_LOGS}/sec.out
touch ${VIDAR_LOGS}/vidar_add2BAD.log

cd ~/src/input


# Send data via perl
cat ${VIDAR_TESTDATA}/a.log   | perl ${VIDAR_UTILS}/throt.pl ${THROTTLE} >> ${VIDAR_INPUT}/auth.log    &
PIDS="${PIDS} $!"
echo "PIDS: [${PIDS}]"
sleep 1
cat ${VIDAR_TESTDATA}/m.log   | perl ${VIDAR_UTILS}/throt.pl ${THROTTLE} >> ${VIDAR_INPUT}/maillog     &
PIDS="${PIDS} $!"
echo "PIDS: [${PIDS}]"
sleep 1
cat ${VIDAR_TESTDATA}/acc.log | perl ${VIDAR_UTILS}/throt.pl ${THROTTLE} >> ${VIDAR_INPUT}/access.log  &
PIDS="${PIDS} $!"
echo "PIDS: [${PIDS}]"

wait

exit

