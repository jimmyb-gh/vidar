#!/bin/sh
# vidar_env.sh - vidar environment variables.
#
# Base directory locations
VIDAR_HOME=$HOME/src/vidar
VIDAR_SEC=${VIDAR_HOME}/sec
VIDAR_SCRIPTS=${VIDAR_HOME}/scripts

# Vidar output files
VIDAR_LOGS=/tmp

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

