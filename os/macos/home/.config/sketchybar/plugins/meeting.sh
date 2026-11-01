#!/bin/zsh
# Shows the next meeting today, e.g. "Standup in 12m" or "Planning at 15:30",
# from the macOS calendars (via icalBuddy). Hidden when there are no more meetings today.
# The icon is a camera when the meeting has a video call link (Zoom, Google Meet, Teams).
# Run by SketchyBar every minute, and every second while it flashes (see the end).
# Click: join the video call, or open today's events (plugins/calendar.sh) without a link.
# On the left of the bar, after the focused app's name.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

CALENDAR_ICON=$'\U000f00f0'
VIDEO_ICON=$'\U000f0567'

# Prints the video call link of the next meeting, if it has one. Calendar invites often
# also contain the link wrapped in a Google redirect; the location usually has the
# plain one, so it is searched first.
next_meeting_link() {
  icalBuddy -n -ea -nc -nrd -li 1 -iep 'location,url,notes' -po 'location,url,notes' \
    eventsToday 2>/dev/null \
    | grep -Eo 'https://[a-z0-9.-]*(zoom\.us/j/|meet\.google\.com/|teams\.microsoft\.com/l/meetup-join/)[^[:space:]"<>]*' \
    | head -1
}

if [[ "$SENDER" == "mouse.clicked" ]]; then
  link="$(next_meeting_link)"
  if [[ -n "$link" ]]; then
    open "$link"
  else
    "$CONFIG_DIR/plugins/calendar.sh" "$NAME"
  fi
  exit 0
fi

# The mouse left the meeting and its events popup.
if [[ "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set "$NAME" popup.drawing=off
  exit 0
fi

# The next event today that has not ended, skipping all-day events.
# Output looks like: "14:30 - 15:00<tab>Standup"
next_event="$(icalBuddy -n -ea -nc -nrd -b '' -li 1 \
  -iep 'datetime,title' -po 'datetime,title' -df '' -tf '%H:%M' -ps $'|\t|' \
  eventsToday 2>/dev/null | head -1)"

if [[ -z "$next_event" ]]; then
  sketchybar --set "$NAME" drawing=off update_freq=60
  exit 0
fi

times="${next_event%%$'\t'*}"     # "14:30 - 15:00"
title="${next_event#*$'\t'}"      # "Standup"
start="${times%% - *}"            # "14:30"

# Long titles are shortened, so the bar stays tidy.
if (( ${#title} > 24 )); then
  title="${title[1,23]}…"
fi

now=$(date +%s)
seconds_until=$(( $(date -j -f '%H:%M:%S' "$start:00" +%s) - now ))
# Rounded up, so it says "in 1m" until it starts, not "now".
minutes_until=$(( (seconds_until + 59) / 60 ))

if (( minutes_until <= 0 )); then
  label="$title now"
elif (( minutes_until < 60 )); then
  label="$title in ${minutes_until}m"
else
  label="$title at $start"
fi

# Yellow when it starts within 10 minutes, red within 5 (or once it has started).
color="$DIM_COLOR"
if (( minutes_until <= 10 )); then color="$YELLOW_COLOR"; fi
if (( minutes_until <= 5 )); then color="$RED_COLOR"; fi

icon="$CALENDAR_ICON"
if [[ -n "$(next_meeting_link)" ]]; then icon="$VIDEO_ICON"; fi

# In the last 5 minutes before it starts, it flashes red: SketchyBar runs this script
# every second then, and each run fades it the other way (to red, to dim, to red, ...).
if (( seconds_until > 0 && seconds_until <= 300 )); then
  flash_color="$RED_COLOR"
  if (( now % 2 == 1 )); then flash_color="$DIM_COLOR"; fi

  sketchybar --set "$NAME" drawing=on update_freq=1 label="$label" icon="$icon" \
             --animate sin 40 --set "$NAME" icon.color="$flash_color" label.color="$flash_color"
  exit 0
fi

# Normally checked every minute; sooner if the flashing starts before then.
next_check=60
if (( seconds_until > 300 && seconds_until - 300 < 60 )); then
  next_check=$(( seconds_until - 300 ))
fi

sketchybar --set "$NAME" drawing=on update_freq="$next_check" label="$label" icon="$icon" \
           icon.color="$color" label.color="$TEXT_COLOR"
