#!/bin/bash
# usage: VIEW=w:h:x:y record.sh <out.mp4> <seconds>   (Studio must be in Play; normally called by auto_take.sh)
# Records Studio's WHOLE 3D viewport (landscape) once; assemble.py cuts the 9:16 Short from it.
# Parks the mouse pointer in the screen corner (it showed in a video) and brings Studio forward.
DIR="$(cd "$(dirname "$0")" && pwd)"
VIEW="${VIEW:-}"   # w:h:x:y of Studio's 3D viewport on YOUR screen (blue border in a full-screen grab; width <= 4096, the H.264 encoder fails above)
[ -n "$VIEW" ] || { echo "set VIEW=w:h:x:y (measure Studio's viewport, see SKILL.md setup)"; exit 1; }
"$DIR/show_studio.sh"; sleep 1.5
[ -x "$DIR/parkmouse" ] || swiftc "$DIR/parkmouse.swift" -o "$DIR/parkmouse"
"$DIR/parkmouse"
( ffmpeg -v error -y -f avfoundation -pixel_format nv12 -framerate 30 -capture_cursor 0 -i "Capture screen 0:none" -t "$2" \
    -vf "crop=$VIEW" -c:v h264_videotoolbox -b:v 100M -pix_fmt yuv420p "$1" > "${1%.mp4}.log" 2>&1 ) &
sleep 1; echo recording
