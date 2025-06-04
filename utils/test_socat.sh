#!/bin/sh
cat t.sh
echo
export COUNT=1
echo 'READY!'
socat -u UDP4-RECV:5555 - | while read -r line
do
    echo "${COUNT}: $line"
    COUNT=`expr ${COUNT} + 1`
done

