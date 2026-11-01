#!/bin/zsh
# Shows the battery level, with an icon for the level and a plug while charging.
# Hidden while plugged in and full.
# Run by SketchyBar every two minutes and when the power source changes.
# Hovering it shows the time remaining in a popup.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"

power_info="$(pmset -g batt)"

# Turns pmset's line, e.g. "80%; discharging; 3:12 remaining", into readable text.
time_remaining() {
  local time="$(echo "$power_info" | grep -Eo '[0-9]+:[0-9]+ remaining' | cut -d' ' -f1)"

  if echo "$power_info" | grep -q 'charged'; then
    echo "Fully charged"
  elif [[ -z "$time" || "$time" == "0:00" ]]; then
    echo "Calculating time remaining…"
  elif echo "$power_info" | grep -q '; charging'; then
    echo "Charging, full in $time"
  else
    echo "$time remaining"
  fi
}

case "$SENDER" in
  mouse.entered)
    sketchybar --animate sin 8 --set "$NAME" background.color="$HOVER_COLOR" \
               --set battery.details label="$(time_remaining)" \
               --set "$NAME" popup.drawing=on
    exit 0
    ;;
  mouse.exited)
    sketchybar --animate sin 8 --set "$NAME" background.color="$TRANSPARENT" \
               --set "$NAME" popup.drawing=off
    exit 0
    ;;
esac
percent="$(echo "$power_info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"

# Macs without a battery report nothing; hide the item there.
if [[ -z "$percent" ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Plugged in and full: nothing worth showing, so hide the item until that changes.
if echo "$power_info" | grep -q 'AC Power' && (( percent >= 100 )); then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  exit 0
fi

# Material Design battery icons (the same icon set as volume and RAM, so the same size),
# from full to empty.
if   [[ "$percent" -ge 90 ]]; then icon=$'\U000f0079'   # full
elif [[ "$percent" -ge 70 ]]; then icon=$'\U000f0080'   # 70%
elif [[ "$percent" -ge 50 ]]; then icon=$'\U000f007e'   # 50%
elif [[ "$percent" -ge 30 ]]; then icon=$'\U000f007c'   # 30%
elif [[ "$percent" -ge 10 ]]; then icon=$'\U000f007a'   # 10%
else                               icon=$'\U000f008e'   # empty
fi

color="$DIM_COLOR"   # only colored when it needs attention
if [[ "$percent" -lt 30 ]]; then color="$YELLOW_COLOR"; fi
if [[ "$percent" -lt 10 ]]; then color="$RED_COLOR"; fi

if echo "$power_info" | grep -q 'AC Power'; then
  icon=$'\U000f0084'   # battery with a lightning bolt, while plugged in
fi

sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color" label="$percent%"
