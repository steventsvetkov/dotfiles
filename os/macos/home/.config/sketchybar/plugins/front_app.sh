#!/bin/zsh
# The focused app's name. Clicking it opens a popup with the app's menus (File, Edit,
# View, ...); picking one opens the real macOS menu. This replaces the macOS menu bar,
# which stays hidden under SketchyBar. (Cmd+, also opens most apps' settings directly.)
#
# Reading and opening menus goes through System Events, which needs the Accessibility
# permission for SketchyBar (macOS asks the first time).

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

# Shows the app's menus in a popup, or closes the popup if it is open.
toggle_app_menus() {
  if [[ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" == "on" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    return
  fi

  sketchybar --remove '/front_app\.menu\..*/' >/dev/null 2>&1   # nothing to remove the first time

  # The frontmost app's process name and its menu titles, one per line.
  local lines=("${(@f)$(osascript \
    -e 'tell application "System Events"' \
    -e '  set app_process to first application process whose frontmost is true' \
    -e '  set titles to name of every menu bar item of menu bar 1 of app_process' \
    -e 'end tell' \
    -e 'set AppleScript'"'"'s text item delimiters to linefeed' \
    -e 'return (name of app_process) & linefeed & (titles as text)')}")

  local process_name="${lines[1]}"
  local changes=()
  local number=0
  local title label

  for title in "${lines[@]:1}"; do
    [[ -n "$title" ]] || continue
    number=$(( number + 1 ))

    # The first menu is the Apple menu; show the Apple logo instead of its name.
    label="$title"
    if [[ "$title" == "Apple" ]]; then label=$'\uf179'; fi

    changes+=(--add item "front_app.menu.$number" popup.front_app
              --set "front_app.menu.$number" icon.drawing=off label="$label"
                    label.padding_left=12 label.padding_right=12
                    click_script="sketchybar --set front_app popup.drawing=off; osascript -e 'tell application \"System Events\" to click menu bar item \"$title\" of menu bar 1 of application process \"$process_name\"'")
  done

  sketchybar "${changes[@]}" --set "$NAME" popup.drawing=on
}


case "$SENDER" in
  front_app_switched)
    # SketchyBar passes the app's name in $INFO. Close the menus of the previous app.
    sketchybar --set "$NAME" label="$INFO" popup.drawing=off
    ;;
  mouse.clicked)
    toggle_app_menus
    ;;
  mouse.exited.global)
    # The mouse left the app name and its popup.
    sketchybar --set "$NAME" popup.drawing=off
    ;;
esac
