#!/bin/sh
#
# vidar_env.sh - vidar environment variables.
#

# Hardcode HOME to /root until we get a proper install script.
# See /etc/rc.local where BOOTING is set.

if [ -f /var/run/BOOTING ]
then
    HOME=/root
fi

# Base directory locations
VIDAR_HOME=$HOME/src/vidar
VIDAR_SEC=${VIDAR_HOME}/sec
VIDAR_SCRIPTS=${VIDAR_HOME}/scripts
VIDAR_UTILS=${VIDAR_HOME}/utils
VIDAR_TESTDATA=${VIDAR_HOME}/testdata

# Vidar output files
#VIDAR_LOGS=/var/log/vidar
VIDAR_LOGS=${VIDAR_HOME}/logs

# DEBUGGING
# SEC dump file location - used for debugging.
# See scripts/sec_start.sh for filename.
VIDAR_DUMP=${VIDAR_LOGS}
VIDAR_DEBUG=${VIDAR_LOGS}
#
# Change these to /dev/null if desired.
VIDAR_SEC_STDERR=${VIDAR_LOGS}/sec_stderr.txt
VIDAR_READSEC_STDERR=${VIDAR_LOGS}/readSEC_stderr.txt
VIDAR_ADD2BAD_STDERR=${VIDAR_LOGS}/add2BAD_stderr.txt

# Vidar PIDS directory.  All pids go in this directory.
VIDAR_PIDS=${VIDAR_HOME}/pids

# Vidar input logs
VIDAR_INPUT=${VIDAR_HOME}/input

# Vidar input files.
# Normally these should be the actual files on the current system
# but they can be overridden here.
# These are INPUT logs, not OUTPUT logs.
AUTHLOG=/var/log/auth.log
EMAILLOG=/var/log/maillog
NGINXLOG=/var/log/nginx/access.log

# These are INPUT logs, not OUTPUT logs.
#AUTHLOG=${VIDAR_INPUT}/auth.log
#EMAILLOG=${VIDAR_INPUT}/maillog
#NGINXLOG=${VIDAR_INPUT}/access.log
PSLOG=${VIDAR_INPUT}/ps.txt
NET4LOG=${VIDAR_INPUT}/net4.txt
NET6LOG=${VIDAR_INPUT}/net6.txt


# Print the environment only if explicitly asked to do so.
#
if [ "X${SHOW_ENV}" = "XY" ]
then
  echo "VIDAR Environment:"
  echo "VIDAR_HOME=     [${VIDAR_HOME}]"
  echo "VIDAR_SEC=      [${VIDAR_SEC}]"
  echo "VIDAR_SCRIPTS=  [${VIDAR_SCRIPTS}]"
  echo "VIDAR_UTILS=    [${VIDAR_UTILS}]"
  echo "VIDAR_PIDS=     [${VIDAR_PIDS}]"
  echo "VIDAR_INPUT=    [${VIDAR_INPUT}]"
  echo "VIDAR_TESTDATA= [${VIDAR_TESTDATA}]"
  echo "DEBUGGING:"
  echo "VIDAR_SEC_STDERR=     [${VIDAR_SEC_STDERR}]"
  echo "VIDAR_READSEC_STDERR= [${VIDAR_READSEC_STDERR}]"
  echo "VIDAR_ADD2BAD_STDERR= [${VIDAR_ADD2BAD_STDERR}]"

  echo "INPUTS:                                                 OUTPUTS:"
  echo "AUTHLOG=  [${AUTHLOG}]            VIDAR_LOGS=[${VIDAR_LOGS}]"
  echo "EMAILLOG= [${EMAILLOG}]"
  echo "NGINXLOG= [${NGINXLOG}]              SEC Dump (Debug) Location:"
  echo "PSLOG   = [${PSLOG}]              VIDAR_DUMP=[${VIDAR_DUMP}]"
  echo "NET4LOG = [${NET4LOG}]"
  echo "NET6LOG = [${NET6LOG}]"
 
fi

