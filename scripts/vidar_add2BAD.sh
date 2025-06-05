#!/bin/sh
#

usage()
{
  echo "vidar_add2BAD.sh [port] - add an entry to IPFW BAD table."
  echo
  echo "This script reads an ip from a UDP port and adds it to the IPFW BAD table."
  echo "The default port is 5555."
  echo "IPFW creates either table if it doesn't exist."
  echo "The checktype function determines (loosely) whether IPv4 or IPv6 is passed."
  echo "IPFW allow either address type to be loaded into the same address table."
  echo
  echo "Must be root to run this script."
  echo "  Exiting..."
  echo
  exit 1
}


# Pick up environment for this run.
. ../vidar_env.sh

# Take port off command line or use a default.

if [ $# -eq 1 ]
then 
  # We were passed a port on the command line.  Pick it up.
  case "$1" in
    *[!0-9]*|'') echo "Parameter [${1}] not a number. Using default port 5555."
      PORT=5555
      ;;
    *) echo  "Parameter is a number. Checking for a valid port."
      PORT=${1}         
      if [ ${PORT} -le 1024 -o ${PORT} -ge 65535 ]
      then
        echo "Parameter [${1}] out of range. Using default port 5555."
        PORT=5555 
      fi
      ;;
  esac
else
  echo "No port parameter supplied. Using default port 5555."
  PORT=5555
fi

echo "PORT is [${PORT}]"


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


# cleanup and exit
cleanup() {
  echo "Terminated.  Cleaning up... removing listener on port ${PORT}."
  echo "Done."
  exit
}




############################ BEGIN #######################

echo
echo "Starting ipfw_add2BAD.sh"
echo

# must be root
ME=`/usr/bin/id -unr`

if [ "X${ME}" != "Xroot" ]
then
  usage;
fi

# Set IPFW commands here. These commands won't be looped like the ones in ipfw_start.sh.
# Keyword "missing" allows to add a table without error even if it already exists.
COMMAND1="/sbin/ipfw -q table BAD create type addr missing"
COMMAND2="/sbin/ipfw -q table BAD lookup "  # requires parameter to complete statement
COMMAND3="/sbin/ipfw -q table BAD add "     # requires parameter to complete statement
COMMAND4="/sbin/ipfw -q table BAD delete "  # requires parameter to complete statement

echo "ipfw_add2BAD: Waiting for data on port ${PORT} ..."

# Open the socat socket on port ${PORT} or the default 5555
#   and pipe into the while loop
# This is pretty robust, but if the writer is
# too fast, it can lose entries.
#
# The Simple Event Correlator (SEC) reads rules for
# authentication (auth.log), mail processing (maillog),
# and web servcies (nginx access, error).
# When a rule finds a match, it outputs an IP address to
# port 5555. The IP address is read by the socat receiver
# below.

/usr/local/bin/socat -u UDP4-RECV:${PORT} - | while read -r IPADDR 
do
    echo "READER: Got line: ${IPADDR}"
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
#    echo -n "Creating or adding to table BAD: "
    
    # COMMAND1 - Create the table if necessary.
    #            This command should not really fail.
    ${COMMAND1}
    RV=$?
    if [ ${RV} -ne 0 ]
    then
        echo
        echo "Error on ipfw table create command [${COMMAND1}]. Return code [${RV}]"
        echo "  Check ipfw module, and try again."
        continue  # Try again.
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
    STATUS=`${COMMAND2} ${IPADDR}`
    RV=$?
    if [ ${RV} -ne 0 ]
    then
        echo
        echo "Error on ipfw table lookup [${COMMAND2} ${IPADDR}]. Return code [${RV}]. Key [${IPADDR}] not found."
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
        #set -x
        echo
        echo "STATUS = [${STATUS}]"
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

exit 0

