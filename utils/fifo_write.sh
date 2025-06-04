#!/bin/sh
FIFO="/tmp/myfifo"

# Make sure FIFO exists
[ -p "$FIFO" ] || mkfifo "$FIFO"

for i in $(seq 1 50000)
do

  echo "${i}: WRITER: Writing data..."

  echo "Hello from WRITER line: ${i} at $(date)" > "$FIFO"

  sleep $1
done

