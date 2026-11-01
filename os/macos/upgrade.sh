#!/usr/bin/env bash
# Upgrades everything on a Mac. Run it through `dotfiles upgrade`.

set -euo pipefail

# -P resolves symlinks, so this is the real folder even when run through ~/.config/dotfiles/os.
OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES="$(cd "$OS_DIR/../.." && pwd)"
source "$DOTFILES/lib/steps.sh"

upgrade_homebrew
upgrade_brewfile "$DOTFILES/shared/Brewfile"
upgrade_brewfile "$OS_DIR/Brewfile"
upgrade_layers
upgrade_runtimes
upgrade_tmux_plugins
