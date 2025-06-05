#!/bin/sh
#
#  sec_start.sh - start up one sec process
#                 configured by all rules in ./sec
#                 and input files accordingly


# Pick up environment for this run.
. ../vidar_env.sh

set -x

AUTHLOG=/var/log/auth.log
EMAILLOG=/var/log/maillog
NGINXLOG=/var/log/nginx/access.log

for i in ${AUTHLOG} ${EMAILLOG} ${NGINXLOG}
do
  if [ ! -f ${i} ]
  then
    touch ${i}
  fi
done

/usr/local/bin/sec  \
  --conf=${VIDAR_SEC}/auth.rules \
  --conf=${VIDAR_SEC}/email.rules \
  --conf=${VIDAR_SEC}/nginx.rules \
  --input=${AUTHLOG} \
  --input=${EMAILLOG} \
  --input=${NGINXLOG}



