# DEPRECATED
# This file is retained for historical reference only.
# Do not use for new development.
# Replaced by: postgres/vidar_add2BAD.pl
# Deprecated as of 2026-02-20
###!/bin/sh
#

usage()
{
  echo "vidar_add2BAD.sh [port] - add an entry to IPFW BAD table."
  echo
  echo "This script reads an IP on standard input and adds it to the IPFW BAD table."
  echo "IPFW creates table BAD if it doesn't exist."
  echo "The checktype function determines (loosely) whether IPv4 or IPv6 is passed."
  echo "IPFW allows either address type to be loaded into the same address table."
  echo
  echo "Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}


# Pick up environment for this run, but don't print it out.

SHOW_ENV="N"
. ../vidar_env.sh


checkip4()
{
  local IPADDY RETVAL IPSTATUS
  IPADDY=$1
  RETVAL=0
  IPSTATUS="GOOD"

  #echo "the ip is [${IPADDY}]"
  if echo "${IPADDY}" | /usr/bin/grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    # echo "Maybe valid IPv4 (syntax)"
  else
    RETVAL=1
    IPSTATUS="FAIL"
    echo "${IPSTATUS}"
    return ${RETVAL}
  fi 

# check every byte to be 0 - 255
  for i in `echo ${IPADDY} | /usr/bin/sed "s/\./ /g"`
  do
    if [ ${i} -ge 0 -a ${i} -le 255 ]
    then
      # echo "i = [${i}]"
      :
    else
      RETVAL=1
      IPSTATUS="FAIL"
    fi
  done
  echo "${IPSTATUS}"
  return  ${RETVAL}
}

checkip6()
{
  local IPADDY RETVAL IPSTATUS
  IPADDY=$1
  RETVAL=0
  IPSTATUS="GOOD"

  # Check for a hexadecimal number
  # Valid addresses are expected from SEC.
  # This is probably overkill, but in reality
  # it's just a simple hack.  We don't **really**
  # validate that it's a valid IPv6 address.

    if echo ${IPADDY} | /usr/bin/egrep -q '^[[:xdigit:]:]+$'; then
      RETVAL=0
      IPSTATUS="GOOD"
    else
      RETVAL=1
      IPSTATUS="FAIL"
    fi
  echo "${IPSTATUS}"
  return  ${RETVAL}
}


checktype()
{
  local IPADDY RETVAL IPSTATUS
  IPADDY=$1
  IPSTATUS=""

  #echo "the ip is [${IPADDY}]"
  # If at least one colon, it's probably IPv6
  if echo "${IPADDY}" | /usr/bin/grep -q  ':'; then
    # echo "Maybe valid IPv6 (syntax)"
    IPSTATUS="IPV6"
  else
    IPSTATUS="IPV4"
  fi
  echo "${IPSTATUS}"
}

# Function to handle cleanup
cleanupINT() {
    NOW=`date`
    echo "vidar_add2BAD.sh terminated on signal INT at ${NOW}." >&2
    exit 0
}
cleanupTERM() {
    NOW=`date`
    echo "vidar_add2BAD.sh terminated on signal TERM at ${NOW}." >&2
    exit 0
}
cleanupPIPE() {
    NOW=`date`
    echo "vidar_add2BAD.sh terminated on signal PIPE at ${NOW}." >&2
    exit 0
}
# Set up signal handlers.
trap cleanupINT  INT
trap cleanupTERM TERM
trap cleanupPIPE PIPE 

############################ BEGIN #######################

echo
echo "Starting vidar_add2BAD.sh"

# must be root
ME=`/usr/bin/id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi

# Save PID for later.
echo "Saving PID to [${VIDAR_PIDS}/add2BAD.pid]"
echo "echo $$ > ${VIDAR_PIDS}/add2BAD.pid"
echo $$ > ${VIDAR_PIDS}/add2BAD.pid
echo "Done."

# Set IPFW commands here. These commands won't be looped like the ones in vidar_start.sh.
# Keyword "missing" allows to add a table without error even if it already exists.
COMMAND1="echo /sbin/ipfw -q table BAD create type addr missing"
COMMAND2="echo /sbin/ipfw -q table BAD lookup "  # requires parameter to complete statement
COMMAND3="echo /sbin/ipfw -q table BAD add "     # requires parameter to complete statement
COMMAND4="echo /sbin/ipfw -q table BAD delete "  # requires parameter to complete statement


# COMMAND1 - Create the table.
#            This command should not really fail.
#            This command does not need to be in the main loop below.

echo "Creating table BAD. "
${COMMAND1}
RV=$?
if [ ${RV} -ne 0 ]
then
  echo
  echo "Error on ipfw table create command [${COMMAND1}]. Return code [${RV}]"
  echo "  Check ipfw module, and try again."
  exit 1 
fi


echo "vidar_add2BAD: Waiting for data on stdin..."

#
# The Simple Event Correlator (SEC) reads rules for
# authentication (auth.log), mail processing (maillog),
# and web servcies (nginx access, error).
# When a rule finds a match, it outputs an IP address to
# stdout.  This script reads that output in a loop
# below.


while :
do
    read IPADDR
    RV=$?
    if [ ${RV} -ge 1 ]
    then
       exit ${RV}
    fi

    echo "Incoming IP: ${IPADDR}"
    PARMTYPE=$(checktype $IPADDR)

    if [ "X${PARMTYPE}" = "XIPV4" ]
    then
        # check the ip
        IPVAL=$(checkip4 $IPADDR)
    else
        IPVAL=$(checkip6 $IPADDR)
    fi
#    echo "IPVAL  = [${IPVAL}]"
#    echo "PARMTYPE = [${PARMTYPE}]"

    if [ "X${IPVAL}" = "XFAIL" ]
    then
         continue  # try again.
    fi
    
    # COMMAND2 - lookup the entry in the BAD table.
    #            The IP address is the key, and the
    #            value is the number of occurances to date.
    # On failure:
    #   - Add the key, no value needed
    # On success:
    #   - Save the key and value in variables
    #   - Delete the key and value
    #   - Increment the value
    #   - Re-add the key and new value
    #
    # This command outputs the key if found, so backtics are necessary.
    # Redirect stderr.  We don't care if the key is not found,
    # but it could be helpful for testing.
    STATUS=`${COMMAND2} ${IPADDR} 2>/dev/null`
    RV=$?
    if [ ${RV} -ne 0 ]
    then
#testing only        echo "Error on ipfw table lookup [${COMMAND2} ${IPADDR}]. Return code [${RV}]. Key [${IPADDR}] not found."
        if [ "${IPADDR}" = "0.0.0.0" ]
        then #don't attempt to add
            echo "Can't add [${IPADDR}]========================================="
            continue
        fi
        echo "Adding key directly."
        ${COMMAND3} ${IPADDR}
        RV=$?
        if [ ${RV} -ne 0 ]
        then
            echo
            echo "Error on ipfw add command [${COMMAND3}]. Return code [${RV}]. Key [${IPADDR}] not not added."
            echo  
        fi
    else # We found a key. Increment value and re-add it.
         # Too bad there is no IPFW update function.
        echo "Found Key = [${STATUS}]"
        NEWKEY=`echo ${STATUS} | awk '{ print $1," ",($2 + 1) }'`
        # Delete existing key (we may need to lock the table at some point)
        ${COMMAND4} ${IPADDR}
        RV=$?
        if [ ${RV} -ne 0 ]
        then
            echo
            echo "Error on ipfw table delete command [${COMMAND3}]. Return code [${RV}]. Key [${IPADDR}] not not added."
            echo  
        fi
        ${COMMAND3} ${NEWKEY}  # add new key
        RV=$?
        if [ ${RV} -ne 0 ]
        then
            echo
            echo "Error on ipfw add command [${COMMAND3}]. Return code [${RV}]. Key [${IPADDR}] not not added."
            echo  
        fi
    fi  
done

echo "Script vidar_add2BAD.sh is exiting now."
exit 0

