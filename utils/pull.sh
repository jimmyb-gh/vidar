#!/bin/sh
#
#  pull.sh  - pull data into auth.log, maillog, and access.log
#             and see it as it goes by.

# Pick up the environment

usage(){
  echo
  echo "Usage: pull.sh"
  echo 
  exit 1
}


# Pick up the environment

export SHOW_ENV="Y"
. ~/src/vidar/vidar_env.sh

cd ${VIDAR_TESTDATA}

pwd


# Open acc.log for reading using file descriptor 3
exec 3< acc.log

while :
do
  # Read one line from Foo
  if read -r line <&3; then
    # Wait for keyboard input (just press Enter to continue)
    echo "Press Enter to continue..."

    # Let's see it
    echo "$line"

    read dummy

    # Append the line to /tmp/bar
    echo "$line" >> ${VIDAR_INPUT}/access.log
  else
    # End of file reached
    echo "End of file reached."
    break
  fi
done

# Close the file descriptor
exec 3<&-

#echo "PIDS: [${PIDS}]"
#sleep 1
#cat ${VIDAR_TESTDATA}/acc.log | perl ${VIDAR_UTILS}/throt.pl ${THROTTLE} >> ${VIDAR_INPUT}/access.log  &
#PIDS="${PIDS} $!"
#echo "PIDS: [${PIDS}]"
#
#wait
#


exit

