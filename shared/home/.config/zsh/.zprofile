# Loaded by login shells. Sets up PATH.
#
# This must happen here and not in .zshenv: on macOS, /etc/zprofile runs after
# .zshenv and moves system folders to the front of PATH.

# OS-specific PATH setup (where Homebrew lives), from os/<name>/home.
source "$ZDOTDIR/os-profile.zsh"

# Personal scripts, including the `dotfiles` command.
export PATH="$HOME/.local/bin:$PATH"
