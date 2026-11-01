#!/bin/zsh
# Shows how many open pull requests on GitHub need you: assigned to you, or waiting for
# your review (asked of you, not of a team you are in). Hidden when there are none, or
# when gh is not logged in.
# Run by SketchyBar every 5 minutes.
# Click: a popup listing them; clicking one opens it in the browser.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"
source "$CONFIG_DIR/helpers/hover.sh"
handle_hover && exit 0

# OR and parentheses need GitHub's advanced search (advanced_search=true below).
QUERY="is:pr is:open archived:false (assignee:@me OR user-review-requested:@me)"

case "$SENDER" in
  mouse.clicked)
    if [[ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" == "on" ]]; then
      sketchybar --set "$NAME" popup.drawing=off
    else
      sketchybar --set "$NAME" popup.drawing=on
    fi
    exit 0
    ;;
  mouse.exited.global)
    # The mouse left the icon and its popup.
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
    ;;
esac

# One line per pull request: repository, number, title and link, separated by tabs.
pull_requests="$(gh api --method GET search/issues -f q="$QUERY" -f advanced_search=true \
  --jq '.items[] | [(.repository_url | split("/") | .[-1]), .number, .title, .html_url] | @tsv' \
  2>/dev/null)"

# Not logged in or offline: keep showing the last list.
(( $? == 0 )) || exit 0

if [[ -z "$pull_requests" ]]; then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  exit 0
fi

# The popup: one line per pull request, like "Fix login redirect ...  dotfiles#12".
# Replace the lines from last time with the current ones.
sketchybar --remove '/github\.pr\..*/' >/dev/null 2>&1   # nothing to remove the first time

changes=()
number=0
while IFS=$'\t' read -r repository pr_number title url; do
  number=$(( number + 1 ))

  # Long titles are shortened, so the popup stays a reasonable width.
  if (( ${#title} > 60 )); then
    title="${title[1,59]}…"
  fi

  changes+=(--add item "github.pr.$number" popup.github
            --set "github.pr.$number" icon="$title" icon.color="$TEXT_COLOR"
                  icon.font="JetBrainsMono Nerd Font Mono:Regular:13.0"
                  icon.padding_left=12 icon.padding_right=12
                  label="$repository#$pr_number" label.color="$DIM_COLOR" label.padding_right=12
                  click_script="sketchybar --set github popup.drawing=off; open '$url'")
done <<< "$pull_requests"

sketchybar "${changes[@]}" --set "$NAME" drawing=on label="$number"
