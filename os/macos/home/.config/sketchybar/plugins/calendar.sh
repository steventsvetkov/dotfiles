#!/bin/zsh
# Opens (or closes) a popup with the rest of today's events, under the item that was
# clicked: the clock, or the meeting item (which passes its name, see meeting.sh).

source "$HOME/.config/dotfiles/theme/sketchybar.sh"

item="${1:-clock}"

# A second click closes the popup.
if [[ "$(sketchybar --query "$item" | jq -r '.popup.drawing')" == "on" ]]; then
  sketchybar --set "$item" popup.drawing=off
  exit 0
fi

# Replace the events from last time with the current ones.
sketchybar --remove '/calendar\.event\..*/' >/dev/null 2>&1   # nothing to remove the first time

# Today's events that have not ended, all-day events first. One per line,
# like "14:30 - 15:00<tab>Standup", or just the title for all-day events.
events=("${(@f)$(icalBuddy -n -nc -nrd -b '' \
  -iep 'datetime,title' -po 'datetime,title' -df '' -tf '%H:%M' -ps $'|\t|' \
  eventsToday 2>/dev/null)}")

changes=()
number=0
for event in $events; do
  [[ -n "$event" ]] || continue
  number=$(( number + 1 ))

  if [[ "$event" == *$'\t'* ]]; then
    time="${event%%$'\t'*}"
    title="${event#*$'\t'}"
  else
    time="all day"
    title="$event"
  fi

  changes+=(--add item "calendar.event.$number" popup."$item"
            --set "calendar.event.$number" icon="$time" icon.color="$DIM_COLOR"
                  icon.font="JetBrainsMono Nerd Font Mono:Regular:13.0" icon.width=110
                  label="$title" label.padding_right=12)
done

if (( number == 0 )); then
  changes+=(--add item calendar.event.none popup."$item"
            --set calendar.event.none icon.drawing=off label="No more events today"
                  label.color="$DIM_COLOR" label.padding_left=12 label.padding_right=12)
fi

sketchybar "${changes[@]}" --set "$item" popup.drawing=on
