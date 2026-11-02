#!/bin/zsh
# Shows how many AI agents (Claude Code, OpenCode) are waiting for you, for input or a
# permission, as tracked by workmux. Hidden when none are; flashes while any is.
# Needs workmux's status hooks: run `workmux setup` once.
# Run by SketchyBar every 5 seconds, and every second while it flashes.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

# Agents across all repositories, counted when their status is "waiting".
waiting="$(workmux status --all --json 2>/dev/null \
  | jq '[.agents[] | select(.status == "waiting")] | length' 2>/dev/null)"

if [[ -z "$waiting" || "$waiting" == "0" ]]; then
  sketchybar --set "$NAME" drawing=off update_freq=5
  exit 0
fi

# Flashing, like the meeting item before a meeting: SketchyBar runs this script every second
# while an agent waits, and each run fades the icon the other way (to yellow, to dim, ...).
flash_color="$YELLOW_COLOR"
if (( $(date +%s) % 2 == 1 )); then flash_color="$DIM_COLOR"; fi

sketchybar --set "$NAME" drawing=on update_freq=1 label="$waiting" \
           --animate sin 40 --set "$NAME" icon.color="$flash_color"
