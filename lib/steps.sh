# Install and upgrade steps that every OS uses. Each os/<name>/install.sh calls
# the steps it needs, in order, passing in anything that differs per OS
# (where Homebrew lives, where the system zshenv is, ...).
#
# Every step is idempotent: it checks the current state first and only changes
# what is missing, so running an install script again changes nothing.
#
# Must work with bash 3.2, the version macOS ships with.

source "$DOTFILES/lib/common.sh"


# ---------------------------------------------------------------------------
# Install steps
# ---------------------------------------------------------------------------

# Records which OS folder this machine uses, for the `dotfiles` command.
remember_os() {
  local os_dir="$1"
  mkdir -p "$(dirname "$OS_LINK")"
  ln -sfn "$os_dir" "$OS_LINK"
}

# Installs Homebrew if needed and puts it on PATH for the rest of the script.
install_homebrew() {
  local prefix="$1"

  info "Homebrew"

  if [[ ! -x "$prefix/bin/brew" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$("$prefix/bin/brew" shellenv)"

  # zsh refuses to load completions from group-writable folders (Homebrew's documented fix).
  chmod go-w "$HOMEBREW_PREFIX/share"
  if [[ -d "$HOMEBREW_PREFIX/share/zsh" ]]; then
    chmod -R go-w "$HOMEBREW_PREFIX/share/zsh"
  fi

  ok "$(brew --version | head -1)"
}

# Installs everything in a Brewfile that is missing.
install_brewfile() {
  local brewfile="$1"

  info "Packages (${brewfile/#$HOME/~})"

  if brew bundle check --file "$brewfile" >/dev/null; then
    ok "All packages installed"
  else
    # --no-upgrade: install what is missing, leave the rest alone. `dotfiles upgrade` upgrades.
    brew bundle install --no-upgrade --file "$brewfile"
  fi
}

# Links the shared configs, then this OS's configs, into $HOME.
link_dotfiles() {
  local os_dir="$1"

  info "Linking dotfiles"

  link_home_folder "$DOTFILES/shared/home"
  link_home_folder "$os_dir/home"
  link_file "$DOTFILES/bin/dotfiles" "$HOME/.local/bin/dotfiles"
  link_opencode_plugins
  remove_stale_links

  ok "All links in place"
}

# OpenCode skips plugin files that are symlinks, so each plugin's whole folder is linked
# into ~/.config/opencode/plugins, where OpenCode finds and loads it.
link_opencode_plugins() {
  local plugin
  for plugin in "$DOTFILES"/shared/opencode-plugins/*/; do
    plugin="${plugin%/}"
    link_file "$plugin" "$HOME/.config/opencode/plugins/$(basename "$plugin")"
  done
}

# Applies each layer (~/.dotfiles-<name>) on top of the core. Every part is optional:
#   Brewfile    packages, installed like the core's
#   home/       configs, linked into $HOME like shared/home
#   install.sh  anything else; it can source "$DOTFILES/lib/common.sh" for the helpers
# Layers add files next to the core's; they never replace one.
install_layers() {
  local layer
  for layer in $(list_layers); do
    info "Layer: $(layer_name "$layer")"

    if [[ -f "$layer/Brewfile" ]]; then
      install_brewfile "$layer/Brewfile"
    fi
    if [[ -d "$layer/home" ]]; then
      link_home_folder "$layer/home"
    fi
    if [[ -x "$layer/install.sh" ]]; then
      DOTFILES="$DOTFILES" "$layer/install.sh"
    fi
  done
}

# zsh reads its config from ~ unless ZDOTDIR is set before it starts.
# The system-wide zshenv is the only place to set it without a file in ~.
set_zdotdir() {
  local system_zshenv="$1"
  local zdotdir_line='export ZDOTDIR="$HOME/.config/zsh"'

  info "zsh config folder"

  if [[ -f "$system_zshenv" ]] && grep -qxF "$zdotdir_line" "$system_zshenv"; then
    ok "ZDOTDIR is set in $system_zshenv"
    return 0
  fi

  append_line "$system_zshenv" "# Added by ~/.dotfiles: zsh reads its config from ~/.config/zsh"
  append_line "$system_zshenv" "$zdotdir_line"
  ok "Set ZDOTDIR in $system_zshenv"
}

# Keeps ~ free of config files: everything lives in ~/.config, ~/.local/state, ~/.cache.
move_old_files_to_xdg() {
  info "XDG folders (nothing in ~)"

  # Folders for history files. Most tools will not create them on their own.
  mkdir -p "$HOME/.local/state/zsh" "$HOME/.local/state/node" \
           "$HOME/.local/state/python" "$HOME/.local/state/less"

  # Files that older setups (or the tools' defaults) left in ~.
  move_to_xdg "$HOME/.zsh_history"  "$HOME/.local/state/zsh/history"
  move_to_xdg "$HOME/.zsh_sessions" "$HOME/.local/state/zsh/sessions"

  # Claude Code keeps its files in ~/.config/claude (CLAUDE_CONFIG_DIR, set in .zshenv).
  # Moving them while it runs would break the running session, so wait until it is closed.
  if [[ -e "$HOME/.claude" || -e "$HOME/.claude.json" ]]; then
    if pgrep -x claude >/dev/null; then
      warn "Claude Code is running. Quit it and run 'dotfiles install' again to move ~/.claude."
    else
      move_to_xdg "$HOME/.claude"      "$HOME/.config/claude"
      move_to_xdg "$HOME/.claude.json" "$HOME/.config/claude/.claude.json"
    fi
  fi

  ok "XDG folders in place"
}

apply_theme() {
  info "Theme"

  # Keep the theme chosen on this machine; fall back to the default on a fresh install.
  local theme
  theme="$(current_theme)"
  set_theme "${theme:-$DEFAULT_THEME}"
}

setup_git_identity() {
  info "Git identity"

  # Name and email differ per machine, so they live in a file that is not committed.
  local identity_file="$HOME/.config/git/local"
  if [[ -f "$identity_file" ]]; then
    ok "Using $identity_file"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    warn "No git identity yet. Run the installer in a terminal to set it."
    return 0
  fi

  local name email
  read -r -p "  Git name: " name
  read -r -p "  Git email: " email
  printf '[user]\n\tname = %s\n\temail = %s\n' "$name" "$email" > "$identity_file"
  ok "Saved to $identity_file"
}

# Signs git commits and tags with this machine's SSH key (the one `gh auth login` can
# create), so GitHub shows them as "Verified". The settings are per machine, so they go
# in ~/.config/git/local next to the name and email, not in the repo.
setup_commit_signing() {
  info "Commit signing"

  local key="$HOME/.ssh/id_ed25519.pub"
  local identity_file="$HOME/.config/git/local"

  if [[ ! -f "$key" ]]; then
    warn "No SSH key yet. Run 'gh auth login' (it can create one), then install again."
    return 0
  fi
  if [[ ! -f "$identity_file" ]]; then
    warn "No git identity yet, so commit signing is not set up."
    return 0
  fi

  git config --file "$identity_file" user.signingkey "$key"
  git config --file "$identity_file" commit.gpgsign true
  git config --file "$identity_file" tag.gpgsign true

  # git trusts signatures from this key for this email (used by git log --show-signature).
  local email
  email="$(git config --file "$identity_file" user.email)"
  echo "$email $(cat "$key")" > "$HOME/.config/git/allowed_signers"

  ok "Signing commits with ${key/#$HOME/~}"
}

install_tmux_plugins() {
  info "tmux plugins"

  local plugins_dir="$HOME/.config/tmux/plugins"
  if [[ ! -d "$plugins_dir/tpm" ]]; then
    git clone --quiet https://github.com/tmux-plugins/tpm "$plugins_dir/tpm"
    ok "Installed tpm (the tmux plugin manager)"
  fi

  # Installs the plugins listed in tmux.conf that are missing; installed ones are skipped.
  "$plugins_dir/tpm/bin/install_plugins" >/dev/null
  ok "Plugins installed"
}

# Installs Claude Code with Anthropic's installer (to ~/.local/bin), for systems
# where Homebrew has no Claude Code package. Its settings go to ~/.config/claude.
install_claude_code_with_installer() {
  info "Claude Code"

  if [[ -x "$HOME/.local/bin/claude" ]]; then
    ok "Already installed"
    return 0
  fi

  curl -fsSL https://claude.ai/install.sh | CLAUDE_CONFIG_DIR="$HOME/.config/claude" bash
  ok "Installed Claude Code"
}

install_runtimes() {
  info "Language runtimes (mise)"
  mise install --yes
  ok "Runtimes installed"
}

set_login_shell() {
  local zsh_path="$1"

  info "Login shell"

  if [[ "$SHELL" == "$zsh_path" ]]; then
    ok "Already $zsh_path"
    return 0
  fi

  # chsh only accepts shells listed in /etc/shells.
  if ! grep -qx "$zsh_path" /etc/shells; then
    append_line /etc/shells "$zsh_path"
  fi
  chsh -s "$zsh_path"
  ok "Changed to $zsh_path (takes effect at next login)"
}


# ---------------------------------------------------------------------------
# Upgrade steps
# ---------------------------------------------------------------------------

upgrade_homebrew() {
  info "Upgrading Homebrew"
  brew update
}

upgrade_brewfile() {
  local brewfile="$1"
  info "Upgrading packages (${brewfile/#$HOME/~})"
  brew bundle upgrade --file "$brewfile"
}

upgrade_layers() {
  local layer
  for layer in $(list_layers); do
    if [[ -f "$layer/Brewfile" ]]; then
      upgrade_brewfile "$layer/Brewfile"
    fi
  done
}

upgrade_runtimes() {
  info "Upgrading mise runtimes"
  mise upgrade --yes
}

upgrade_tmux_plugins() {
  info "Upgrading tmux plugins"
  "$HOME/.config/tmux/plugins/tpm/bin/update_plugins" all
}
