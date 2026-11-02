# macOS system settings and Mac app settings. Used by the scripts in this folder.
# This file only defines functions; sourcing it changes nothing.


# ---------------------------------------------------------------------------
# System settings
# ---------------------------------------------------------------------------

# Writes a macOS setting if it does not have the wanted value yet.
# Succeeds only when it changed something, so callers can restart the affected app.
write_macos_default() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local value="$4"

  # `defaults read` prints booleans as 1 and 0.
  local expected="$value"
  if [[ "$type" == "-bool" && "$value" == "true" ]]; then
    expected="1"
  elif [[ "$type" == "-bool" && "$value" == "false" ]]; then
    expected="0"
  fi

  if [[ "$(defaults read "$domain" "$key" 2>/dev/null)" == "$expected" ]]; then
    return 1
  fi

  defaults write "$domain" "$key" "$type" "$value"
  ok "Set $domain $key to $value"
}

apply_macos_settings() {
  info "macOS settings"

  # Dock: hide it, and group windows by app in Mission Control (recommended by AeroSpace).
  local dock_changed=false
  if write_macos_default com.apple.dock autohide -bool true; then dock_changed=true; fi
  if write_macos_default com.apple.dock expose-group-apps -bool true; then dock_changed=true; fi
  if [[ "$dock_changed" == true ]]; then
    killall Dock
  fi

  # Menu bar: hide it (SketchyBar takes its place; it still slides in at the top edge),
  # and give it a background when it does show, instead of fully transparent.
  if write_macos_default NSGlobalDomain _HIHideMenuBar -bool true; then
    # The saved setting only applies after logging out; System Events applies it right away.
    osascript -e 'tell application "System Events" to set autohide menu bar of dock preferences to true'
  fi
  write_macos_default NSGlobalDomain SLSMenuBarUseBlurredAppearance -bool true || true

  # F1-F12 send F keys, like on a PC keyboard; Fn+F1-F12 gives brightness, volume and so on.
  # Karabiner follows this setting too. activateSettings applies it without logging out.
  if write_macos_default NSGlobalDomain com.apple.keyboard.fnState -bool true; then
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  fi

  # Turn off "Displays have separate Spaces" (recommended by AeroSpace).
  if write_macos_default com.apple.spaces spans-displays -bool true; then
    warn "Log out and back in for the Spaces setting to take effect."
  fi

  ok "macOS settings applied"
}


# ---------------------------------------------------------------------------
# App settings
# ---------------------------------------------------------------------------
#
# Mac apps keep settings in preference domains (~/Library/Preferences/<id>.plist).
# Those files cannot be symlinked: macOS replaces the link when the app saves.
# Instead, each app listed in $APP_PREFS_DIR as <bundle-id>.plist is copied:
#   - save_app_preferences:    this Mac -> repo  (before commits, by before-commit.sh)
#   - restore_app_preferences: repo -> this Mac  (only when the app has no settings yet)
#
# To track a new app, create an empty $APP_PREFS_DIR/<bundle-id>.plist and run `dotfiles push`.
# Keys that are usage history or window state rather than settings can be listed,
# one per line, in $APP_PREFS_DIR/<bundle-id>.ignore; they are left out of the repo.

APP_PREFS_DIR="$OS_DIR/preferences"

# Succeeds if the app has any settings on this Mac.
# A domain whose settings were deleted still reads as an empty "{}", which counts as none.
has_app_settings() {
  local settings
  settings="$(defaults read "$1" 2>/dev/null)" || return 1
  [[ "$settings" != $'{\n}' ]]
}

# Copies the current settings of every tracked app into the repo, as readable XML.
save_app_preferences() {
  local file domain
  for file in "$APP_PREFS_DIR"/*.plist; do
    [[ -e "$file" ]] || continue
    domain="$(basename "$file" .plist)"

    # Nothing to save if the app has never been opened on this Mac.
    if ! has_app_settings "$domain"; then
      continue
    fi

    defaults export "$domain" "$file"
    plutil -convert xml1 "$file"
    remove_ignored_keys "$file" "$APP_PREFS_DIR/$domain.ignore"
  done
}

# Deletes the keys listed in an .ignore file (one per line, # for comments) from a plist.
remove_ignored_keys() {
  local plist="$1"
  local ignore_file="$2"
  [[ -f "$ignore_file" ]] || return 0

  local key
  while IFS= read -r key; do
    if [[ -z "$key" || "$key" == \#* ]]; then
      continue
    fi
    # The key may be missing (e.g. the app never wrote it); that is fine.
    plutil -remove "$key" "$plist" 2>/dev/null || true
  done < "$ignore_file"
}

# Loads saved settings for every tracked app that has no settings on this Mac yet.
# Never overwrites settings that already exist, so local changes are safe.
restore_app_preferences() {
  info "App settings"

  local file domain
  for file in "$APP_PREFS_DIR"/*.plist; do
    [[ -s "$file" ]] || continue
    domain="$(basename "$file" .plist)"

    if has_app_settings "$domain"; then
      ok "Kept existing settings for $domain"
    else
      defaults import "$domain" "$file"
      ok "Restored settings for $domain"
    fi
  done
}
