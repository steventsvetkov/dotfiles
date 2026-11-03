#!/usr/bin/env bash
# Upgrades everything on Arch. Run it through `dotfiles upgrade`.
# On Omarchy, system packages are upgraded by Omarchy's own update instead.

set -euo pipefail

# -P resolves symlinks, so this is the real folder even when run through ~/.config/dotfiles/os.
OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES="$(cd "$OS_DIR/../.." && pwd)"
source "$DOTFILES/lib/steps.sh"

upgrade_homebrew
upgrade_aged_packages
upgrade_tmux_plugins

# Claude Code updates itself in the background.
