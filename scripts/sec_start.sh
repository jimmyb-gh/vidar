#!/bin/sh
#
#  sec_start.sh - start up one sec process
#                 configured by all rules in ./sec
#                 and input files accordingly

echo 
echo "========  VIDAR: sec_start.sh  ========="
echo



# Pick up environment for this run, but don't print it out.
. ../vidar_env.sh Q

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

#  --detach \

/usr/local/bin/sec  \
  --tail \
  --log=${VIDAR_LOGS}/sec.output \
  --pid=${VIDAR_PIDS}/sec.pid \
  --conf=${VIDAR_SEC}/auth.rules \
  --conf=${VIDAR_SEC}/email.rules \
  --conf=${VIDAR_SEC}/nginx.rules \
  --input=${AUTHLOG} \
  --input=${EMAILLOG} \
  --input=${NGINXLOG} 

exit 0


