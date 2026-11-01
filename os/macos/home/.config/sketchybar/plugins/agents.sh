#!/bin/zsh
# Shows how many Claude Code agents are waiting for you (for input or a permission),
# as tracked by workmux. Hidden when none are. Run by SketchyBar every 5 seconds.
# Needs workmux's status hooks in Claude Code: run `workmux setup --hooks` once.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

# Agents across all repositories, counted when their status is "waiting".
waiting="$(workmux status --all --json 2>/dev/null \
  | jq '[.agents[] | select(.status == "waiting")] | length' 2>/dev/null)"

if [[ -z "$waiting" || "$waiting" == "0" ]]; then
  sketchybar --set "$NAME" drawing=off
else
  sketchybar --set "$NAME" drawing=on label="$waiting"
fi
