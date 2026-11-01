#!/bin/zsh
# Shows how much of the Claude plan's 5-hour session limit is left, e.g. "96%".
# Turns yellow at 30% left and red at 10%.
# Hovering it shows every limit (session, weekly, ...) and when it resets.
# The numbers come from ai-usagebar (installed by mise), which uses Claude Code's login.
# Run by SketchyBar every 5 minutes.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"

case "$SENDER" in
  mouse.entered)
    sketchybar --animate sin 8 --set "$NAME" background.color="$HOVER_COLOR" \
               --set "$NAME" popup.drawing=on
    exit 0
    ;;
  mouse.exited)
    sketchybar --animate sin 8 --set "$NAME" background.color="$TRANSPARENT" \
               --set "$NAME" popup.drawing=off
    exit 0
    ;;
esac

# Claude's limits, like {"label": "Session (5h)", "percent": 3, "value": "3%",
# "detail": "Resets in 3h 39m · ..."}. mise runs ai-usagebar, so mise's folders do not
# have to be on SketchyBar's PATH.
limits="$(mise exec -- ai-usagebar usage --json 2>/dev/null \
  | jq -c '.entries[] | select(.id == "anthropic" and .error == null) | .metrics')"

# Offline, or not logged in: keep showing the last numbers.
[[ -n "$limits" ]] || exit 0

used="$(echo "$limits" | jq -r 'first(.[] | select(.label | startswith("Session"))) | .percent')"
left=$(( 100 - used ))

color="$DIM_COLOR"
if (( left <= 30 )); then color="$YELLOW_COLOR"; fi
if (( left <= 10 )); then color="$RED_COLOR"; fi

# The popup: one line per limit, like "Session (5h)   97% left  Resets in 3h 39m".
# Percentages are turned around to what is left, like on the bar; other values
# (extra usage in dollars) are shown as they are.
# Replace the lines from last time with the current ones.
sketchybar --remove '/claude_usage\.limit\..*/' >/dev/null 2>&1   # nothing to remove the first time

changes=()
number=0
while IFS=$'\t' read -r name value detail; do
  number=$(( number + 1 ))
  changes+=(--add item "claude_usage.limit.$number" popup.claude_usage
            --set "claude_usage.limit.$number" icon="$name" icon.color="$DIM_COLOR"
                  icon.font="JetBrainsMono Nerd Font Mono:Regular:13.0" icon.width=130
                  icon.padding_left=12 label="$(printf '%-11s' "$value")$detail"
                  label.padding_right=12)
done < <(echo "$limits" | jq -r '.[]
  | (if (.value | endswith("%")) then "\(100 - .percent)% left" else .value end) as $value
  | [.label, $value, (.detail | split(" · ")[0])] | @tsv')

sketchybar "${changes[@]}" \
  --set "$NAME" drawing=on icon.color="$color" label="$left%"
