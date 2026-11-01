#!/bin/zsh
# The volume item. Shows the output volume, and reacts to the mouse:
#   scroll       change the volume
#   click        mute / unmute
#   right-click  popup to choose the output device (speakers, headphones, ...)
# Run by SketchyBar at startup, when the volume changes, and on mouse events.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

current_volume() {
  osascript -e 'output volume of (get volume settings)'
}

is_muted() {
  [[ "$(osascript -e 'output muted of (get volume settings)')" == "true" ]]
}

# Updates the icon and label from the current volume and mute state.
show_volume() {
  local volume="$1"

  if is_muted || (( volume == 0 )); then
    icon=$'\U000f0581'   # speaker, muted
  elif (( volume >= 60 )); then
    icon=$'\U000f057e'   # speaker, high
  elif (( volume >= 20 )); then
    icon=$'\U000f0580'   # speaker, medium
  else
    icon=$'\U000f057f'   # speaker, low
  fi

  sketchybar --set "$NAME" icon="$icon" label="$volume%"
}

# Opens a popup listing the output devices; clicking one switches to it.
# A second right-click closes the popup.
toggle_output_menu() {
  if [[ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" == "on" ]]; then
    sketchybar --set "$NAME" popup.drawing=off
    return
  fi

  sketchybar --remove '/volume\.device\..*/' >/dev/null 2>&1   # nothing to remove the first time

  local current_id="$(SwitchAudioSource -c -t output -f json | jq -r '.id')"
  local changes=()
  local id device_name color

  # One line per device, like "83<tab>MacBook Air Speakers".
  SwitchAudioSource -a -t output -f json | jq -r '"\(.id)\t\(.name)"' |
  while IFS=$'\t' read -r id device_name; do
    color="$TEXT_COLOR"
    if [[ "$id" == "$current_id" ]]; then color="$ACCENT_COLOR"; fi

    changes+=(--add item "volume.device.$id" popup.volume
              --set "volume.device.$id" icon.drawing=off label="$device_name"
                    label.color="$color" label.padding_left=12 label.padding_right=12
                    click_script="SwitchAudioSource -i $id -t output; sketchybar --set volume popup.drawing=off")
  done

  sketchybar "${changes[@]}" --set "$NAME" popup.drawing=on
}


case "$SENDER" in
  mouse.scrolled)
    # $SCROLL_DELTA is positive when scrolling up. Two percent per scroll step.
    new_volume=$(( $(current_volume) + SCROLL_DELTA * 2 ))
    (( new_volume > 100 )) && new_volume=100
    (( new_volume < 0 )) && new_volume=0
    osascript -e "set volume output volume $new_volume"
    ;;
  mouse.clicked)
    if [[ "$BUTTON" == "right" ]]; then
      toggle_output_menu
    else
      SwitchAudioSource -m toggle -t output >/dev/null
      show_volume "$(current_volume)"
    fi
    ;;
  mouse.exited.global)
    # The mouse left the volume item and its popup.
    sketchybar --set "$NAME" popup.drawing=off
    ;;
  volume_change)
    show_volume "$INFO"
    ;;
  *)
    show_volume "$(current_volume)"
    ;;
esac
