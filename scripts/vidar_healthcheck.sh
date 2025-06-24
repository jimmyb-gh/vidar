#!/bin/sh
#
#   vidar_healthcheck.sh  - send health check notifications through all inputs
#                           and check if output received in sec.out.
#      Must be root to run this script.

usage()
{
  echo
  echo "usage: vidar_healthcheck.sh  - send health check notifications through all inputs."
  echo
  echo "  Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}


# Pick up environment for this run, but don't print it out.

export SHOW_ENV="N"
. ../vidar_env.sh


ME=`id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi

# Set up for this check.  These are all we need.

echo "AUTH_HEALTH_CHECK" >> ${AUTHLOG}
echo "EMAIL_HEALTH_CHECK" >> ${EMAILLOG}
echo "NGINX_HEALTH_CHECK" >> ${NGINXLOG}
echo
echo "Health Checks Sent. Tail sec.log to view results."
echo "It may take a moment or two for checks to appear."
echo "Done."

exit

