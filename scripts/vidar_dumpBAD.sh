#!/bin/sh
#
#   vidar_dumpBAD.sh  - collect the entire BAD table and save it to a file.
#      Must be root to run this script.

usage()
{
  echo
  echo "usage: vidar_dumpBAD.sh  - dump the entire BAD table and save it to a file."
  echo
  echo "  Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}


# Pick up environment for this run, but don't print it out.

SHOW_ENV="N"
. ../vidar_env.sh


ME=`id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi

# Set up for this dump
cd ${VIDAR_LOGS}

# Make sure archive directory exists.
mkdir -p ${VIDAR_LOGS}/archive

export ARCHIVEDIR=${VIDAR_LOGS}/archive

# ISO 8601 date spec
DATESPEC=`date -j "+%Y%m%dT%H%M%S"`

echo -n "Dumping BAD ... "

COMMAND="/sbin/ipfw table BAD list"

# echo "${COMMAND} \> ${ARCHIVEDIR}/BAD.${DATESPEC}"

STATUS=`${COMMAND} > ${ARCHIVEDIR}/BAD.${DATESPEC}`


if [ $? -ne 0 ]
then
  echo
  echo "Error on ipfw command [${COMMAND}]. Return code [${STATUS}]"
  echo "  Check ipfw module, and try again."
  exit 2
else
  echo "done. BAD table dumped in ${VIDAR_LOGS}."
  ls -al ${ARCHIVEDIR}/BAD.${DATESPEC}
  # Remove existing link in logs file.
  # Note that vidar_importBAD.sh uses this link.
  rm ${VIDAR_LOGS}/BAD.txt
  # And recreate it
  ln -s ${ARCHIVEDIR}/BAD.${DATESPEC} ${VIDAR_LOGS}/BAD.txt
  ls -al ${VIDAR_LOGS}
  echo
fi

exit 0

