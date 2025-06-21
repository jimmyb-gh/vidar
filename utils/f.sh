#!/bin/sh

#set -x

PORT=12345 # Replace with your actual port
FIFO_PATH="/tmp/myfifo.$$" # Unique FIFO path

mkfifo "$FIFO_PATH" # Create the named pipe

# Run socat in a subshell, writing to the named pipe
/usr/local/bin/socat -u UDP4-RECV:${PORT} - > "$FIFO_PATH" &
SOCAT_PID=$!

COUNT=0

# Read from the named pipe in the parent shell
echo "Ready..."

while read -r IPADDR
do
    printf "%d: %s\n" "$COUNT" "$IPADDR"
    # Do something with IPADDR in the parent shell context
#    PARENT_VAR="Last IP: $IPADDR"
    if [ "$IPADDR" = "STOP" ]; then
        echo "Stopping parent script."
        break # Exit the while loop
    fi
    COUNT=`expr $COUNT + 1`
done < "$FIFO_PATH"

echo "Value of PARENT_VAR in parent shell: $PARENT_VAR"

# Clean up
kill "$SOCAT_PID" 2>/dev/null # Kill socat process
rm "$FIFO_PATH" # Remove the named pipe


