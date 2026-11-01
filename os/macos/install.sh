#!/usr/bin/env bash
# Sets up a Mac. Run it through ~/.dotfiles/install.sh or `dotfiles install`.

set -euo pipefail

# -P resolves symlinks, so this is the real folder even when run through ~/.config/dotfiles/os.
OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES="$(cd "$OS_DIR/../.." && pwd)"
source "$DOTFILES/lib/steps.sh"
source "$OS_DIR/settings.sh"

remember_os "$OS_DIR"

install_homebrew /opt/homebrew
install_brewfile "$DOTFILES/shared/Brewfile"
install_brewfile "$OS_DIR/Brewfile"

link_dotfiles "$OS_DIR"
# Karabiner replaces its config file when it saves, which would break a link to
# the file, so its whole folder is linked instead.
link_file "$OS_DIR/karabiner" "$HOME/.config/karabiner"
install_layers

set_zdotdir /etc/zshenv
move_old_files_to_xdg
apply_macos_settings
restore_app_preferences
apply_theme
setup_git_identity
setup_commit_signing
install_tmux_plugins
install_runtimes
set_login_shell /bin/zsh
