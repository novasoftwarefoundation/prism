#!/bin/sh
# The web comparison screen at 100% and at 200% zoom, into $1. The dashed line is the
# 393px screen's edge; anything past it runs off the screen.
set -e
out=$1
here=$(cd "$(dirname "$0")" && pwd)
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "$out"
shot() {
  "$chrome" --headless=new --disable-gpu --hide-scrollbars \
    --user-data-dir="$here/../chrome-profile" --screenshot="$out/$1" \
    --window-size=520,$2 --force-device-scale-factor=2 "file://$here/$3" >/dev/null 2>&1
}
shot web-100.png 560 screen.html
shot web-200.png 1500 screen-zoom.html
