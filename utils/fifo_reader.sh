#!/bin/sh
FIFO="/tmp/myfifo"

# Make sure FIFO exists
[ -p "$FIFO" ] || mkfifo "$FIFO"


# cleanup and exit
cleanup() {
  echo "Terminated.  Cleaning up..."
  rm -f ${FIFO}
  exit
}

trap cleanup  EXIT INT ABRT TERM USR1

echo "READER: Waiting for data..."

# Open the pipe once for reading
while :
do

  while IFS= read -r line < ${FIFO}
  do
    echo "READER: Got line: $line"
  done
#  sleep 1
done

