#!/bin/sh
#
#   vidar_importBAD.sh  - (re)import the entire BAD table back into IPFW.
#                         Input is the .../logs/BAD.txt file from vidar_dumpBAD.sh
#      Script will exit if a record is already in the IPFW BAD table.
#      Must be root to run this script.

usage()
{
  echo
  echo "usage: vidar_importBAD.sh  - (re)import the entire BAD table into IPFW from a dump file."
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


echo -n "Importing BAD.txt dump file ... "
LINES=`wc -l  ${VIDAR_LOGS}/BAD.txt| awk '{print $1}'`
echo "${LINES} lines in dump file."

COMMAND="/sbin/ipfw table BAD add "

COUNT=0


for i in `cat ${VIDAR_LOGS}/BAD.txt | awk '{print $1}'`
do
    if [ "X${i}" = "X9999:9999:9999:9999:9999:9999:9999:9999/128" ]
    then
        break
    fi
    echo [${i}]
    #echo STATUS=${COMMAND} ${i}
    STATUS=`${COMMAND} ${i}`
    if [ $? -ne 0 ]
    then
        echo
        echo "Error on ipfw command [${COMMAND} ${i}]. Return code [${STATUS}]"
        echo "  Check ipfw module and BAD.txt, and try again."
#        exit 2
    else
        COUNT=$((COUNT + 1))
    fi
done

echo "Done. Processed [$COUNT] lines."

exit

