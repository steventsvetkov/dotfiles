#!/bin/zsh
# Updates the workspace items: which one is focused, which screen's bar each is on,
# the icons of the apps on each, and hides empty workspaces (except visible ones).
# Run by SketchyBar on AeroSpace, app focus and display events (see sketchybarrc).
#
# Kept fast on purpose, so the bar follows workspace switches without a visible delay:
#   1. the focused workspace is highlighted first, before anything slow happens;
#      the highlight slides from the old workspace to the new one (--animate);
#   2. then the app icons are updated, asking AeroSpace once for all windows.
#
# With several screens, each screen's bar shows only the workspaces on that screen.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"

# One line per workspace, like "2|1|false": the workspace, the screen it is on
# (numbered like SketchyBar numbers displays) and whether it is shown on that screen.
typeset -A screen_of is_visible
workspaces=()
while IFS='|' read -r workspace screen visible; do
  workspaces+=("$workspace")
  screen_of[$workspace]="$screen"
  is_visible[$workspace]="$visible"
done < <(aerospace list-workspaces --all \
  --format '%{workspace}|%{monitor-appkit-nsscreen-screens-id}|%{workspace-is-visible}')

# AeroSpace passes the focused workspace with its event; other events have to ask.
focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"


# Slides the highlight behind the focused workspace.
# SketchyBar cannot place an item at a given position, so the highlight is an item that
# takes no space in the bar (workspace_indicator, width=0) and draws its icon background
# further right: padding_left moves it to the workspace, icon.width makes it as wide.
move_indicator() {
  # Where the focused workspace is, e.g. "display-1 61 43": its bar, x position and width.
  local target=($(sketchybar --query "workspace.$focused" \
    | jq -r '.bounding_rects | to_entries[0] | "\(.key) \(.value.origin[0]) \(.value.size[0])"'))
  local target_bar="${target[1]}"
  local target_x="${target[2]%.*}"
  local target_width="${target[3]%.*}"

  # Where the highlight is now, and where it would be without its padding.
  local indicator=($(sketchybar --query workspace_indicator \
    | jq -r '"\(.bounding_rects | to_entries[0] | "\(.key) \(.value.origin[0])") \(.geometry.padding_left)"'))
  local indicator_bar="${indicator[1]}"
  local left_edge=$(( ${indicator[2]%.*} - indicator[3] ))

  local position=(padding_left=$(( target_x - left_edge )) icon.width="$target_width")

  if [[ "$indicator_bar" == "$target_bar" ]]; then
    sketchybar --animate sin 10 --set workspace_indicator "${position[@]}"
  else
    # On another screen: jump there instead of sliding across.
    sketchybar --set workspace_indicator display="${target_bar#display-}" "${position[@]}"
  fi
}


# --- 1. Highlight the focused workspace -------------------------------------

changes=()
for workspace in $workspaces; do
  if [[ "$workspace" == "$focused" ]]; then
    changes+=(--set "workspace.$workspace" drawing=on display="${screen_of[$workspace]}"
              icon.color="$ACCENT_COLOR" label.color="$TEXT_COLOR")
  else
    changes+=(--set "workspace.$workspace" display="${screen_of[$workspace]}"
              icon.color="$DIM_COLOR" label.color="$DIM_COLOR")
  fi
  # Clears a hover background left behind by a click (see workspace_hover.sh).
  changes+=(background.color="$TRANSPARENT")
done
sketchybar --animate sin 10 "${changes[@]}"
move_indicator


# --- 2. App icons, and hide empty workspaces --------------------------------

source "$CONFIG_DIR/helpers/icon_map.sh"

# One line per window, like "2|Ghostty". Collect each workspace's app icons,
# one icon per app, e.g. icons[2]=" :ghostty: :zen_browser:".
typeset -A icons seen
while IFS='|' read -r workspace app; do
  [[ -n "$app" ]] || continue
  # Several windows of one app: one icon. (The key is built in a variable first,
  # because a | written inside seen[...] would be read as a pipe.)
  key="$workspace|$app"
  [[ -z "${seen[$key]}" ]] || continue
  seen[$key]=1

  __icon_map "$app"   # sets $icon_result
  icons[$workspace]="${icons[$workspace]} $icon_result"
done < <(aerospace list-windows --all --format '%{workspace}|%{app-name}')

changes=()
for workspace in $workspaces; do
  if [[ -n "${icons[$workspace]}" ]]; then
    # The number, then the app icons.
    changes+=(--set "workspace.$workspace" drawing=on label="${icons[$workspace]}"
              label.drawing=on icon.padding_right=4)
  elif [[ "${is_visible[$workspace]}" == "true" ]]; then
    # Empty, but shown on a screen: just the number, with the same padding on both sides.
    changes+=(--set "workspace.$workspace" drawing=on label.drawing=off icon.padding_right=8)
  else
    changes+=(--set "workspace.$workspace" drawing=off)
  fi
done
sketchybar "${changes[@]}"

# Showing or hiding workspaces and icons moved and resized the focused one.
move_indicator
