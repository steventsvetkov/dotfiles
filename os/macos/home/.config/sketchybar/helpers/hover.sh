# Hover effect shared by the plugins: a subtle background fades in while the mouse
# is over a clickable item. Each plugin starts with: handle_hover && exit 0

# Handles mouse.entered / mouse.exited for the item $NAME.
# Succeeds if the event was a hover event (so the caller can stop there).
handle_hover() {
  case "$SENDER" in
    mouse.entered) sketchybar --animate sin 8 --set "$NAME" background.color="$HOVER_COLOR" ;;
    mouse.exited)  sketchybar --animate sin 8 --set "$NAME" background.color="$TRANSPARENT" ;;
    *)             return 1 ;;
  esac
}
