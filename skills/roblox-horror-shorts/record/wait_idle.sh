#!/bin/bash
# waits until keyboard/mouse have been idle for $1 seconds (max 40 min)
for i in $(seq 1 2400); do
  idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
  [ "$idle" -ge "$1" ] && echo "idle ${idle}s" && exit 0
  sleep 1
done
exit 1
