#!/bin/bash
# usage: auto_take.sh <out.mp4> <seconds> [from]   Studio must be in Play.
# Waits for 60 s of no keyboard/mouse, films, tells Studio to start via the bridge, then checks nobody touched the Mac.
cd "$(dirname "$0")"; GO=../../roblox/go.txt; rm -f "$GO"
eval "$(grep -m1 '^VIEW=' record.sh)"   # same crop as record.sh (honours an env VIEW)
caffeinate -d -w $$ &   # keep the display awake while we wait and film
# the screen must be the size the crop expects (selected by NAME: a phone camera can take device index 1)
ffmpeg -v error -y -f avfoundation -pixel_format nv12 -framerate 30 -capture_cursor 0 -i "Capture screen 0:none" -frames:v 1 -vf "crop=$VIEW,scale=10:-1" -f null - 2>/dev/null || { echo "SCREEN SIZE CHANGED: re-measure the crop"; exit 1; }
./wait_idle.sh 60 || { echo "NO IDLE WINDOW"; exit 1; }
./record.sh "$1" "$2"
sleep 1; echo "go ${3:-0}" > "$GO"
sleep $(( $2 + 3 )); rm -f "$GO"
idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
if [ "$idle" -ge "$2" ]; then echo "VALID take (idle ${idle}s)"; else echo "TOUCHED take: Mac was used ${idle}s ago (kept as ${1%.mp4}_touched.mp4: check frames for a cursor/window change)"; mv "$1" "${1%.mp4}_touched.mp4"; fi
