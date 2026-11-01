#!/bin/zsh
# Reloads the bar when the height it should have changed, e.g. after a resolution change.
# SketchyBar also sends display_change when it starts, so only reload when the height
# actually differs; otherwise every reload would trigger the next one.

wanted="$("$CONFIG_DIR/helpers/bar_height.sh")"
current="$(sketchybar --query bar | jq -r '.height')"

if [[ "$wanted" != "$current" ]]; then
  sketchybar --reload
fi
