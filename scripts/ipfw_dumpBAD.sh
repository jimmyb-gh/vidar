#!/bin/sh
#
# ipfw_dumpBAD.sh  - collect the entire BAD table and save it to a file.
#    Must be root to run this script.

usage()
{
  echo
  echo "usage: ipfw_dumpBAD.sh  - dump the entire BAD table and save it to a file."
  echo
  echo "  Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}

ME=`id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi


echo -n "Dumping BAD ... "

COMMAND="/sbin/ipfw table BAD list"

# echo "${COMMAND} \> BAD.TXT"

STATUS=`${COMMAND} > BAD.TXT`

if [ $? -ne 0 ]
then
  echo
  echo "Error on ipfw command [${COMMAND}]. Return code [${STATUS}]"
  echo "  Check ipfw module, and try again."
  exit 2
else
  echo "done. BAD table dumped."
  # show proof here.
  echo
fi

exit 0


