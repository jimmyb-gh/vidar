#!/bin/sh
#
echo 
echo "========  VIDAR: vidar_env.sh  ========="
echo

# vidar_env.sh - vidar environment variables.
#
# Base directory locations
VIDAR_HOME=$HOME/src/vidar
VIDAR_SEC=${VIDAR_HOME}/sec
VIDAR_SCRIPTS=${VIDAR_HOME}/scripts

# Vidar output files
#VIDAR_LOGS=/var/log/vidar
VIDAR_LOGS=${VIDAR_HOME}/logs

# Vidar PIDS directory.  All pids go in this directory.
VIDAR_PIDS=${VIDAR_HOME}/pids

# Vidar input files.
# Normally these should be the actual files on the current system
# but they can be overridden here.
# These are INPUT logs, not OUTPUT logs.
# They should eventually move to vidar_env.sh.
#AUTHLOG=/var/log/auth.log
#EMAILLOG=/var/log/maillog
#NGINXLOG=/var/log/nginx/access.log

# These are INPUT logs, not OUTPUT logs.
AUTHLOG=/root/src/input/auth.log
EMAILLOG=/root/src/input/maillog
NGINXLOG=/root/src/input/access.log

# Vidar UDP port, used in Sec rules and in vidar_add2BAD.sh
VIDAR_UDP=5555

# Print the environment unless explicitly asked not to do so.

if [ "$(echo "$1" | tr '[:lower:]' '[:upper:]')" != "Q" ]
then
  echo "VIDAR Environment:"
  echo "VIDAR_HOME=    [${VIDAR_HOME}]"
  echo "VIDAR_SEC=     [${VIDAR_SEC}]"
  echo "VIDAR_SCRIPTS= [${VIDAR_SCRIPTS}]"
  echo "VIDAR_PIDS=    [${VIDAR_PIDS}]"
  echo "VIDAR_UDP=     [${VIDAR_UDP}]"
  echo "INPUTS:                                          OUTPUTS:"
  echo "AUTHLOG=  [${AUTHLOG}]            VIDAR_LOGS=[${VIDAR_LOGS}]"
  echo "EMAILLOG= [${EMAILLOG}]"
  echo "NGINXLOG= [${NGINXLOG}]"
fi

