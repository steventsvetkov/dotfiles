# Loaded by every zsh, including scripts. Only environment variables belong here.
#
# zsh finds this folder through ZDOTDIR, which install.sh sets in the system-wide
# zshenv (/etc/zshenv on macOS), so no zsh files are needed in ~.

export DOTFILES="$HOME/.dotfiles"


# --- XDG base directories ---------------------------------------------------
# Every tool keeps its files in these folders, never directly in ~.

export XDG_CONFIG_HOME="$HOME/.config"       # settings
export XDG_CACHE_HOME="$HOME/.cache"         # can be deleted any time
export XDG_DATA_HOME="$HOME/.local/share"    # data the tools own
export XDG_STATE_HOME="$HOME/.local/state"   # history, logs

# Tools that would otherwise write to ~, pointed at the folders above.
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node/repl_history"
export PYTHON_HISTORY="$XDG_STATE_HOME/python/history"
export LESSHISTFILE="$XDG_STATE_HOME/less/history"


# --- Editor -----------------------------------------------------------------

export EDITOR="nvim"
export VISUAL="$EDITOR"


# --- OS-specific ------------------------------------------------------------
# Environment variables for this OS only, from os/<name>/home.

source "$ZDOTDIR/os-env.zsh"


# --- Secrets ----------------------------------------------------------------
# API keys and tokens for this machine, in every zsh (so scripts and agents see them too).
# Not in the repo.

if [[ -f "$ZDOTDIR/local.zshenv" ]]; then
  source "$ZDOTDIR/local.zshenv"
fi
