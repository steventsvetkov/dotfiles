#!/usr/bin/env bash
# Sets up Arch Linux, typically Omarchy. Run it through ~/.dotfiles/install.sh or `dotfiles install`.
#
# On Omarchy: never edit files in ~/.local/share/omarchy. Override them from
# ~/.config instead, by adding files to os/arch/home.

set -euo pipefail

# -P resolves symlinks, so this is the real folder even when run through ~/.config/dotfiles/os.
OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES="$(cd "$OS_DIR/../.." && pwd)"
source "$DOTFILES/lib/steps.sh"

# Installs the packages in a list file that are not installed yet.
install_pacman_packages() {
  local list_file="$1"

  info "System packages (${list_file#"$DOTFILES"/})"

  local missing=""
  local package
  for package in $(read_package_list "$list_file"); do
    # base-devel is a group, not a package, so pacman -Qg checks it.
    if ! pacman -Q "$package" >/dev/null 2>&1 && ! pacman -Qg "$package" >/dev/null 2>&1; then
      missing="$missing $package"
    fi
  done

  if [[ -z "$missing" ]]; then
    ok "All installed"
    return 0
  fi

  # $missing is a space-separated list, so it is left unquoted on purpose.
  sudo pacman -S --needed --noconfirm $missing
  ok "Installed:$missing"
}


remember_os "$OS_DIR"

install_pacman_packages "$OS_DIR/pacman-packages.txt"

install_homebrew /home/linuxbrew/.linuxbrew
install_brewfile "$DOTFILES/shared/Brewfile"

link_dotfiles "$OS_DIR"
install_layers
set_zdotdir /etc/zsh/zshenv
move_old_files_to_xdg
apply_theme
setup_git_identity
setup_commit_signing
install_tmux_plugins
install_claude_code_with_installer
install_runtimes
set_login_shell /usr/bin/zsh
