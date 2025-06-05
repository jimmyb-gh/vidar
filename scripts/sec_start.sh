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

/usr/local/bin/sec  \
  --conf=${VIDAR_SEC}/auth.rules \
  --conf=${VIDAR_SEC}/email.rules \
  --conf=${VIDAR_SEC}/nginx.rules \
  --input=${AUTHLOG} \
  --input=${EMAILLOG} \
  --input=${NGINXLOG}



