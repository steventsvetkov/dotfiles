#!/bin/zsh
# Shows the AeroSpace mode while it is not the normal one, e.g. "SERVICE".
# AeroSpace sends aerospace_mode_change with MODE=<name> (see aerospace.toml).

if [[ -z "$MODE" || "$MODE" == "main" ]]; then
  sketchybar --set "$NAME" drawing=off
else
  sketchybar --set "$NAME" drawing=on label="${(U)MODE}"   # (U): upper case
fi
