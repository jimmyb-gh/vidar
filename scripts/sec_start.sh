#!/bin/sh
#
#  sec_start.sh - start up one sec process
#                 configured by all rules in ./sec
#                 and input files accordingly

set -x

RULESDIR=$HOME/src/vidar/sec

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
  --conf=${RULESDIR}/auth.rules \
  --conf=${RULESDIR}/email.rules \
  --conf=${RULESDIR}/nginx.rules \
  --input=${AUTHLOG} \
  --input=${EMAILLOG} \
  --input=${NGINXLOG}



