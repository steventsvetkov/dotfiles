#!/bin/zsh
# Sets the bar's height when the height it should have changed, e.g. after a resolution change.
#
# Opening the lid sends a burst of display_change events for up to ~20 seconds, and while the
# screens settle the notch can read as missing. Reloading the whole bar on each reading made it
# reload over and over, so this script:
#   - changes only the height (instant, keeps every item) instead of reloading,
#   - runs one check at a time: events that arrive while a check runs are dropped, and the
#     running check covers them by waiting for the screens to settle,
#   - acts only once the measured height is the same for STABLE_READINGS seconds in a row.

STABLE_READINGS=3
MAX_SECONDS=30
LOCK="${TMPDIR:-/tmp}/sketchybar-display-change.lock"

# mkdir is atomic: it fails when another check already holds the lock.
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK"' EXIT

last=""
same=0
for (( second = 0; second < MAX_SECONDS; second++ )); do
  sleep 1
  height="$("$CONFIG_DIR/helpers/bar_height.sh")"

  if [[ "$height" == "$last" ]]; then
    (( same++ ))
  else
    last="$height"
    same=1
  fi

  if (( same >= STABLE_READINGS )); then
    break
  fi
done

# Never settled: leave the bar as it is rather than act on a passing value.
(( same >= STABLE_READINGS )) || exit 0

current="$(sketchybar --query bar | jq -r '.height')"
if [[ "$last" != "$current" ]]; then
  sketchybar --bar height="$last"
fi
