#!/usr/bin/env bash
# Upgrades everything on Ubuntu. Run it through `dotfiles upgrade`.

set -euo pipefail

# -P resolves symlinks, so this is the real folder even when run through ~/.config/dotfiles/os.
OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES="$(cd "$OS_DIR/../.." && pwd)"
source "$DOTFILES/lib/steps.sh"

info "Upgrading system packages (apt)"
sudo apt-get update
sudo apt-get upgrade -y

upgrade_homebrew
upgrade_aged_packages
upgrade_tmux_plugins

# Claude Code updates itself in the background.
