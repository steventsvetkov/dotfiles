# Interactive shell setup. Sections run top to bottom, and the order matters where noted.

# Terminals that start a non-login shell (common on Linux) skip .zprofile, so load it here.
if [[ -z "$HOMEBREW_PREFIX" ]]; then
  source "$ZDOTDIR/.zprofile"
fi


# --- History ----------------------------------------------------------------

HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

setopt EXTENDED_HISTORY      # save timestamps
setopt SHARE_HISTORY         # share history between open terminals
setopt HIST_IGNORE_ALL_DUPS  # keep only the latest copy of a repeated command
setopt HIST_IGNORE_SPACE     # commands starting with a space are not saved
setopt HIST_REDUCE_BLANKS


# --- Options ----------------------------------------------------------------

setopt AUTO_CD               # type a folder name to cd into it
setopt INTERACTIVE_COMMENTS  # allow # comments on the command line
bindkey -e                   # emacs keys: Ctrl+A, Ctrl+E, ...


# --- Completion -------------------------------------------------------------

# Extra completions must be on fpath before compinit runs.
fpath=("$HOMEBREW_PREFIX/share/zsh-completions" $fpath)

mkdir -p "$XDG_CACHE_HOME/zsh"
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '[%d]'       # fzf-tab shows these as group headers
zstyle ':completion:*' menu no                          # fzf-tab replaces the menu

# fzf-tab: preview folders when completing cd, and use the theme's fzf colors.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
zstyle ':fzf-tab:*' use-fzf-default-opts yes


# --- Plugins (installed by Homebrew) ----------------------------------------

# fzf-tab must load after compinit and before the two plugins below.
source "$HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.zsh"
source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"


# --- Tools ------------------------------------------------------------------

# fzf: Ctrl+R history search, Ctrl+T file search, Alt+C cd. Colors come from the theme.
export FZF_DEFAULT_OPTS_FILE="$HOME/.config/dotfiles/theme/fzf"
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline-right"
export FZF_DEFAULT_COMMAND="fd --type file --hidden --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
source <(fzf --zsh)

eval "$(zoxide init zsh)"         # z <part of a path> jumps to a folder you visited before
eval "$(mise activate zsh)"       # language runtimes (node, python, ...)
eval "$(starship init zsh)"       # prompt, configured in ~/.config/starship.toml


# --- Aliases and functions --------------------------------------------------

source "$ZDOTDIR/aliases.zsh"

# Shell settings that layers (~/.dotfiles-<name>) add, like work aliases and environment.
for file in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$file"
done

# Machine-specific settings and secrets. Not in the repo.
if [[ -f "$ZDOTDIR/local.zsh" ]]; then
  source "$ZDOTDIR/local.zsh"
fi
