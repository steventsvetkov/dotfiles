#!/bin/zsh
# Prints the height the bar should have: the MacBook notch area plus one point (which
# looks better), or 39 points when no screen has a notch (e.g. only an external monitor).
# The notch's height in points depends on the display resolution, so it is measured.

notch_height="$("$CONFIG_DIR/helpers/notch_height.sh")"

if (( notch_height > 0 )); then
  echo $(( notch_height + 1 ))
else
  echo 39
fi
