#!/bin/zsh
# Shows the date and time, e.g. "Thu 30 Oct  14:05". Run by SketchyBar as each minute
# starts (see the end), and when the Mac wakes up.
# Clicking it opens today's events (plugins/calendar.sh).

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

# The mouse left the clock and its calendar popup.
if [[ "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set "$NAME" popup.drawing=off
  exit 0
fi

now=$(date +%s)

# The next run is when the next minute starts, so the time changes right on the minute.
seconds_to_next_minute=$(( 60 - now % 60 ))

sketchybar --set "$NAME" label="$(date -r "$now" '+%a %d %b  %H:%M')" \
                         update_freq="$seconds_to_next_minute"
