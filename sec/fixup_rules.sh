#!/bin/sh
#
#
#  fixup_rules.sh - fix *.rules.setup files to
#                   substitute proper varialbles
#                   from  vidar_env.sh.
#
#  This script copies and  modifies *.rules.setup files
#  by substituting all @@@XXXXX@@@ tags with the value
#  defined in vidar_env.sh.
#
#  The reason for this is that sec cannot apply substitutions
#  on rules files.  They are read "as is".

# Pick up vidar environment for this run, and print it out unless "Q"uiet.

SHOW_ENV="N"
. ../vidar_env.sh

# Fixup logs.
echo "Value VIDAR_LOGS=${VIDAR_LOGS} will be used..."
echo "s]@@@LOGS@@@]${VIDAR_LOGS}]" > f.sed

cat auth.rules.setup     | sed  -f f.sed   > auth.rules
cat email.rules.setup    | sed  -f f.sed   > email.rules
cat nginx.rules.setup    | sed  -f f.sed   > nginx.rules
cat calendar.rules.setup | sed  -f f.sed   > calendar.rules

echo "Fixup done."
