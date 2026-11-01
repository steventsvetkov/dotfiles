#!/bin/zsh
# Shows how many Slack mentions and direct messages are unread. Hidden when there are
# none (other unread messages don't count) or Slack is not running.
# It is the badge Slack puts on its Dock icon, read with lsappinfo.
# Run by SketchyBar every 10 seconds. Click: open Slack.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

if [[ "$SENDER" == "mouse.clicked" ]]; then
  open -a Slack
  exit 0
fi

# With a badge, lsappinfo prints a line like: "StatusLabel"={ "label"="3" }
# Only the full (-long) output has it; `-only StatusLabel` prints nothing on newer macOS.
badge="$(lsappinfo info -long com.tinyspeck.slackmacgap \
  | sed -n 's/.*"label"="\(.*\)".*/\1/p')"

# The badge is a number for mentions and direct messages, and a dot for other unread
# messages, which are ignored.
if [[ "$badge" =~ ^[0-9]+$ ]]; then
  sketchybar --set "$NAME" drawing=on label="$badge"
else
  sketchybar --set "$NAME" drawing=off
fi
