#!/bin/zsh
# Opens an app's own menu bar menu (the icon apps put on the right of the macOS menu bar),
# which is hidden under SketchyBar. Usage: status_menu.sh <app process name>, e.g. Vorssaint.
#
# SketchyBar cannot show these icons itself on macOS 26+ (see sketchybarrc), so the bar
# has its own item per app, and clicking it opens the app's real menu through System Events.
# If the app has no menu bar icon at the moment (some apps hide it, or have not created it
# yet after a restart), the app itself is opened instead, so the click always does something.

app="$1"

if ! osascript -e "tell application \"System Events\" to tell application process \"$app\" to click menu bar item 1 of menu bar 2" >/dev/null 2>&1; then
  open -a "$app"
fi
