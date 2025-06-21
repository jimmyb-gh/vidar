#!/bin/sh
#
#  sec_start.sh - start up one sec process
#                 configured by all rules in ./sec
#                 and input files accordingly

# Pick up environment for this run, but don't print it out.

SHOW_ENV="N"
. ../vidar_env.sh

# set -x

for i in ${AUTHLOG} ${EMAILLOG} ${NGINXLOG} ${AUTHLOG}
do
  if [ ! -f ${i} ]
  then
    touch ${i}
  fi
done

# Function to handle cleanup
cleanup() {
    NOW=`date`
    echo "start_sec.sh Received signal at ${NOW}, exiting..." >&2
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

# --debug  : sec debug level 4=only necessary output, 6=debug
# --tail   : keep reading input, even if changed
# --log    : sec output goes here
# --pid    : file holds sec process id
# --dump   : sec dump file for debugging
# --conf   : a sec configuration file (multiples possible)
# --input  : a sec input file (multiples possible)
# --intcontexts : explicitly set option for using internal contexts

# NOTE: Do not use --detach.  Sec is daemonized and this messes
#       up the input stream for vidar_add2BAD.sh (which then exits).

# Input files with "=WORD" are applying the internal context WORD.
# The rules files now have internal contexts for each of these.
# See sec(1) for details on internal contexts.

/usr/local/bin/sec  \
  --debug=4 \
  --tail \
  --log=${VIDAR_LOGS}/sec.out \
  --pid=${VIDAR_PIDS}/sec.pid \
  --dump=${VIDAR_DUMP}/sec.dump \
  --conf=${VIDAR_SEC}/activity.rules \
  --conf=${VIDAR_SEC}/auth.rules \
  --conf=${VIDAR_SEC}/calendar.rules \
  --conf=${VIDAR_SEC}/email.rules \
  --conf=${VIDAR_SEC}/nginx.rules \
  --input=${AUTHLOG}=AUTH \
  --input=${EMAILLOG}=EMAIL \
  --input=${NGINXLOG}=NGINX \
  --input=${PSLOG}=PROC \
  --input=${NET4LOG}=NETW \
  --input=${NET6LOG}=NETW  \
  --intcontexts

exit 0


