#!/bin/bash
# restore and front the Studio window (only call once the Mac is idle): a minimized window renders white
osascript -e 'tell application "System Events" to tell process "RobloxStudio" to set value of attribute "AXMinimized" of window 1 to false' >/dev/null 2>&1
osascript -e 'tell application "RobloxStudio" to activate'
