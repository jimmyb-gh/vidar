#!/bin/sh
#
#  sec_start.sh - start up one sec process
#                 configured by all rules in ./sec
#                 and input files accordingly

# Pick up environment for this run, but don't print it out.

SHOW_ENV="N"
. ../vidar_env.sh

# set -x

for i in ${AUTHLOG} ${EMAILLOG} ${NGINXLOG}
do
  if [ ! -f ${i} ]
  then
    touch ${i}
  fi
done

# Function to handle cleanup
cleanup() {
    echo "start_sec.sh Received signal, exiting..." >&2
    echo "Killing sec via pid file."

    if [ -f ${VIDAR_PIDS}/sec.pid ]
    then
        kill -TERM `cat ${VIDAR_PIDS}/sec.pid`
        rm ${VIDAR_PIDS}/sec.pid
    fi
    exit 0
}

# Set up signal handlers
trap cleanup INT TERM

#
# Put in a sanity check here to ensure that the
# rules files have been fixed up with fixup_rules.sh
#

# --tail   : keep reading input, even if changed
# --log    : sec output goes here
# --pid    : file holds sec process id
# --conf   : a sec configuration file (multiples possible)
# --input  : a sec input file (multiples possible)

# NOTE: Do not use --detach.  Sec is daemonized and this messes
#       up the input stream for vidar_add2BAD.sh (which then exits).

/usr/local/bin/sec  \
  --tail \
  --log=${VIDAR_LOGS}/sec.output \
  --pid=${VIDAR_PIDS}/sec.pid \
  --conf=${VIDAR_SEC}/auth.rules \
  --conf=${VIDAR_SEC}/email.rules \
  --conf=${VIDAR_SEC}/nginx.rules \
  --conf=${VIDAR_SEC}/calendar.rules \
  --input=${AUTHLOG} \
  --input=${EMAILLOG} \
  --input=${NGINXLOG} 

exit 0


