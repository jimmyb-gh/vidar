#!/bin/sh
#
#  sec_start.sh - start up one sec process
#                 configured by all rules in ./sec
#                 and input files accordingly


# Pick up environment for this run.
. ../vidar_env.sh

set -x

for i in ${AUTHLOG} ${EMAILLOG} ${NGINXLOG}
do
  if [ ! -f ${i} ]
  then
    touch ${i}
  fi
done


#
# Put in a sanity check here to ensure that the
# rules files have been fixed up with fixup_rules.sh
#

# --detach : become a daemon
# --tail   : keep reading input, even if changed
# --log    : sec output goes here
# --pid    : file holds sec process id
# --conf   : a sec configuration file (multiples possible)
# --input  : a sec input file (multiples possible)


/usr/local/bin/sec  \
  --detach \
  --tail \
  --log=${VIDAR_LOGS}/sec.output \
  --pid=${VIDAR_SEC}/sec.pid \
  --conf=${VIDAR_SEC}/auth.rules \
  --conf=${VIDAR_SEC}/email.rules \
  --conf=${VIDAR_SEC}/nginx.rules \
  --input=${AUTHLOG} \
  --input=${EMAILLOG} \
  --input=${NGINXLOG} 


