# shellcheck shell=bash
# shellcheck disable=SC2034 # read by upgrade-brew-aged.sh, which sources this
# Changed from upstream: the list is this repo's casks that update themselves.
# Homebrew skips those on `brew upgrade`, so upgrade-brew-aged.sh upgrades them
# here, age-gated. Turn each app's own updater off, or it keeps updating past the gate.
# Layers add their own casks in ~/.config/upgrade-aged/casks (one name per line).
BREW_UPDATED_CASKS=(betterdisplay ghostty karabiner-elements tailscale-app visual-studio-code vorssaint zen zoom)

if [[ -f "$HOME/.config/upgrade-aged/casks" ]]; then
  while IFS= read -r _cask; do
    if [[ -n "$_cask" && "$_cask" != \#* ]]; then
      BREW_UPDATED_CASKS+=("$_cask")
    fi
  done < "$HOME/.config/upgrade-aged/casks"
fi
