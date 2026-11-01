#!/usr/bin/env bash
# Sets up this machine from the dotfiles repo.
#
# This is the only place that checks which OS we are on. It runs the matching
# os/<name>/install.sh, which does the actual work. Safe to run any number of
# times; run it (or `dotfiles install`) after changing anything in the repo.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES/lib/common.sh"

# Prints the name of the folder in os/ for this machine.
detect_os() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  elif [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif grep -q '^ID=ubuntu$' /etc/os-release 2>/dev/null; then
    echo "ubuntu"
  else
    die "Unsupported system. Supported: macOS, Ubuntu (including WSL), Arch (Omarchy)."
  fi
}

os="$(detect_os)"
info "Installing dotfiles for $os"
"$DOTFILES/os/$os/install.sh"
info "Done. Open a new terminal to pick up the changes."
