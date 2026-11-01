#!/bin/zsh
# Shows a red "offline" warning when there is no network connection; hidden otherwise.
# Run by SketchyBar every 30 seconds and when Wi-Fi changes.

# Without a default route, nothing outside this Mac can be reached.
if route -n get default >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off
else
  sketchybar --set "$NAME" drawing=on
fi
