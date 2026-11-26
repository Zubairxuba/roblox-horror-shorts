#!/bin/bash
# usage: READY=yes auto_take.sh <out.mp4> <seconds> [from]    Studio must be in Play.
# PRIVACY (2026-11-26: an "idle" Mac was on a video call and the take filmed it). A take records the real screen, so it runs ONLY
#   - after the user has said, now, that they are ready (READY=yes),
#   - with no microphone in use (a call sends no keyboard or mouse input, so idle time alone proves nothing),
#   - with Studio frontmost for the whole recording. Anything else: stop and delete.
# run from projects/<slug>/ (copied there): ../../roblox/go.txt is the file the Director polls through the bridge
cd "$(dirname "$0")"; GO=../../roblox/go.txt; rm -f "$GO"
[ "$READY" = yes ] || { echo "ASK THE USER FIRST, then run with READY=yes"; exit 1; }
# any app holding the microphone, except Apple's always-on speech daemon (corespeechd, Siri listening): that is not a call
mic() {
  for p in $(pmset -g assertions | awk '/Created for PID:/ {pid=$4; sub(/\./, "", pid)} /Resources: .*audio-in/ {print pid}'); do
    c=$(ps -o comm= -p "$p"); case "$c" in */CoreSpeech.framework/corespeechd) ;; *) echo "mic held by ${c##*/}" >&2; return 0 ;; esac
  done
  return 1
}
front() { osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'; }
locked() { ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes'; }
bad() { locked && echo "screen locked" && return 0; mic && echo "microphone in use" && return 0; f=$(front); [ "$f" != RobloxStudio ] && echo "front app is $f" && return 0; return 1; }
drop() { pkill -INT -f "avfoundation.*$1" 2>/dev/null; sleep 1; rm -f "$1" "${1%.mp4}.log" "$GO"; echo "TAKE ABORTED AND DELETED: $2"; exit 1; }
caffeinate -d -w $$ &
export VIEW="${VIEW:?set VIEW=w:h:x:y, see record.sh}"
# the screen must be the size the crop expects (selected by NAME: a phone camera can take device index 1)
ffmpeg -v error -y -f avfoundation -pixel_format nv12 -framerate 30 -capture_cursor 0 -i "Capture screen 0:none" -frames:v 1 -vf "crop=$VIEW,scale=10:-1" -f null - 2>/dev/null || { echo "SCREEN SIZE CHANGED: re-measure VIEW"; exit 1; }
mic && { echo "NOT FILMING: microphone in use (a call?)"; exit 1; }
./wait_idle.sh 60 || { echo "NO IDLE WINDOW"; exit 1; }
{ mic || locked; } && { echo "NOT FILMING: microphone in use or screen locked"; exit 1; }
./show_studio.sh; sleep 2
why=$(bad) && { echo "NOT FILMING: $why"; exit 1; }
./record.sh "$1" "$2"
( sleep 1; echo "go ${3:-0}" > "$GO" ) &
for _ in $(seq 1 $(( $2 + 2 ))); do why=$(bad) && drop "$1" "$why"; sleep 1; done
rm -f "$GO"
idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
echo "VALID take (Studio stayed in front; idle ${idle}s)"
