#!/bin/zsh
# A reminder to sync the dotfiles repo: shown while it has changes that are not committed
# or pushed yet, or commits on GitHub that are not pulled yet; hidden when all is in sync.
# Hovering it shows what is out of sync. Run by SketchyBar every 2 minutes.

source "$HOME/.config/dotfiles/theme/sketchybar.sh"

DOTFILES="$HOME/.dotfiles"
# Checking GitHub for new commits needs the network, so it is done only this often.
FETCH_EVERY_MINUTES=30

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

repo_git() {
  git -C "$DOTFILES" "$@"
}

# Shows a popup line when its count is not zero, e.g. "3 changed files: dotfiles push".
set_popup_line() {
  local item="$1"
  local count="$2"
  local text="$3"
  if (( count > 0 )); then
    sketchybar --set "$item" drawing=on label="$count $text"
  else
    sketchybar --set "$item" drawing=off
  fi
}

changes="$(repo_git status --porcelain | wc -l | tr -d ' ')"
unpushed=0
behind=0

# Only once the repo is on GitHub (has an upstream branch).
if repo_git rev-parse '@{upstream}' >/dev/null 2>&1; then
  fetch_head="$DOTFILES/.git/FETCH_HEAD"
  if [[ ! -f "$fetch_head" || -n "$(find "$fetch_head" -mmin +$FETCH_EVERY_MINUTES)" ]]; then
    repo_git fetch --quiet 2>/dev/null
  fi
  unpushed="$(repo_git rev-list --count '@{upstream}..HEAD')"
  behind="$(repo_git rev-list --count 'HEAD..@{upstream}')"
fi

if (( changes + unpushed + behind == 0 )); then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  exit 0
fi

set_popup_line dotfiles.changes "$changes" "changed files: dotfiles push"
set_popup_line dotfiles.unpushed "$unpushed" "commits not pushed: dotfiles push"
set_popup_line dotfiles.behind "$behind" "new commits on GitHub: dotfiles pull"
sketchybar --set "$NAME" drawing=on
