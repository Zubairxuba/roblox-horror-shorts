#!/bin/bash
# usage: record.sh <out.mp4> <seconds>   (Studio must be in Play)
# Records Studio's WHOLE viewport (landscape) once; assemble.py cuts the 9:16 Short and the 16:9 long video from it.
# Parks the mouse pointer in the screen corner (it showed in the video), brings Studio forward.
DIR="$(cd "$(dirname "$0")" && pwd)"
VIEW="${VIEW:-4096:2014:8:394}"   # w:h:x:y of Studio's 3D viewport on YOUR screen (measure it from a full-screen grab; width <= 4096)
open -a RobloxStudio; sleep 1.2
[ -x "$DIR/parkmouse" ] || swiftc "$DIR/parkmouse.swift" -o "$DIR/parkmouse"
"$DIR/parkmouse"
( ffmpeg -v error -y -f avfoundation -pixel_format nv12 -framerate 30 -capture_cursor 0 -i "Capture screen 0:none" -t "$2" \
    -vf "crop=$VIEW" -c:v h264_videotoolbox -b:v 60M -pix_fmt yuv420p "$1" > "${1%.mp4}.log" 2>&1 ) &
sleep 1; echo recording
