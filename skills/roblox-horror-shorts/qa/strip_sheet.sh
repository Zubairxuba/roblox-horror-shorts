#!/bin/bash
# usage: strip_sheet.sh <video> <out.png> <start_s> <step_s> <count> [cols]   (9:16 centre strip of every step_s, tiled)
V="$1"; OUT="$2"; S="$3"; STEP="$4"; N="$5"; COLS="${6:-9}"
W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$V")
H=${W#*,}; W=${W%,*}; SW=$(( H*9/16 )); X=$(( (W-SW)/2 ))
ROWS=$(( (N+COLS-1)/COLS ))
"${FFMPEG:-ffmpeg}" -v error -y -ss "$S" -i "$V" -vf "fps=1/$STEP,crop=$SW:$H:$X:0,scale=150:-1,drawtext=text='%{pts\:hms}':x=4:y=4:fontsize=14:fontcolor=yellow,tile=${COLS}x${ROWS}" -frames:v 1 "$OUT"
