#!/bin/zsh
# Hover effect for workspace items. Like helpers/hover.sh, but the focused workspace
# keeps its highlight: hovering it changes nothing, and leaving other workspaces
# fades back to no background.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"

workspace="${NAME#workspace.}"
if [[ "$workspace" == "$(aerospace list-workspaces --focused)" ]]; then
  exit 0
fi

case "$SENDER" in
  mouse.entered) sketchybar --animate sin 8 --set "$NAME" background.color="$HOVER_COLOR" ;;
  mouse.exited)  sketchybar --animate sin 8 --set "$NAME" background.color="$TRANSPARENT" ;;
esac
