#!/usr/bin/env bash
# Runs before `dotfiles status` and `dotfiles push` look at the repo.
# Copies the settings of tracked Mac apps into os/macos/preferences, so changes
# made in the apps show up as changes in the repo.

set -euo pipefail

# -P resolves symlinks, so this is the real folder even when run through ~/.config/dotfiles/os.
OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES="$(cd "$OS_DIR/../.." && pwd)"
source "$DOTFILES/lib/common.sh"
source "$OS_DIR/settings.sh"

save_app_preferences
