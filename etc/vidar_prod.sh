#!/bin/sh
#
# vidar_env.sh - vidar environment variables.
#
# This is the PRODUCTION vidar_env.sh

export VIDAR_ENVIRONMENT="PRODUCTION"

# Base directory locations
# Testing
#export VIDAR_HOME=/home/vidar/src/vidar

# Production
export VIDAR_HOME=/usr/local/vidar

export VIDAR_SEC=${VIDAR_HOME}/sec
export VIDAR_SCRIPTS=${VIDAR_HOME}/scripts
export VIDAR_UTILS=${VIDAR_HOME}/utils
export VIDAR_TESTDATA=${VIDAR_HOME}/testdata
export VIDAR_ETC=${VIDAR_HOME}/etc
export VIDAR_LIBEXEC=${VIDAR_HOME}/libexec

# Vidar output files
# export VIDAR_LOGS=/var/log/vidar
export VIDAR_LOGS=${VIDAR_HOME}/logs

# DEBUGGING
# SEC dump file location - used for debugging.
# See scripts/run_sec.sh for filename.
export VIDAR_DUMP=${VIDAR_LOGS}
export VIDAR_DEBUG=${VIDAR_LOGS}
#
# Change these to /dev/null if desired.
export VIDAR_SEC_STDERR=${VIDAR_LOGS}/sec_stderr.txt
export VIDAR_READSEC_STDERR=${VIDAR_LOGS}/readSEC_stderr.txt
export VIDAR_ADD2BAD_STDERR=${VIDAR_LOGS}/add2BAD_stderr.txt

# Vidar PIDS directory.  All pids go in this directory.
export VIDAR_PIDS=${VIDAR_HOME}/pids

# Vidar input logs
export VIDAR_INPUT=${VIDAR_HOME}/input

#
# Vidar input files.
# Normally these should be the actual files on the current system
# but they can be overridden here.
# These are INPUT logs, not OUTPUT logs.
# Use these files for production.
export AUTHLOG=/var/log/auth.log
export EMAILLOG=/var/log/maillog
export NGINXLOG=/var/log/nginx/access.log

export PSLOG=${VIDAR_INPUT}/ps.txt
export NET4LOG=${VIDAR_INPUT}/net4.txt
export NET6LOG=${VIDAR_INPUT}/net6.txt


# Print the environment only if explicitly asked to do so.
#
if [ "X${SHOW_ENV}" = "XY" ]
then
  echo "VIDAR Environment: ${VIDAR_ENVIRONMENT}"
  echo "VIDAR_HOME=     [${VIDAR_HOME}]"
  echo "VIDAR_SEC=      [${VIDAR_SEC}]"
  echo "VIDAR_SCRIPTS=  [${VIDAR_SCRIPTS}]"
  echo "VIDAR_UTILS=    [${VIDAR_UTILS}]"
  echo "VIDAR_PIDS=     [${VIDAR_PIDS}]"
  echo "VIDAR_INPUT=    [${VIDAR_INPUT}]"
  echo "VIDAR_TESTDATA= [${VIDAR_TESTDATA}]"
  echo "VIDAR_ETC=      [${VIDAR_ETC}]"
  echo "VIDAR_LIBEXEC=  [${VIDAR_LIBEXEC}]"
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

