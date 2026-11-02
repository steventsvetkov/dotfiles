# Aliases and small shell functions. Loaded by .zshrc.

# Listing files (eza)
alias ls='eza --icons=auto --group-directories-first'
alias ll='ls -l --git'
alias la='ll -a'
alias lt='eza --tree --level=2 --icons=auto'

# Reading files (bat). Behaves like plain cat when piped.
alias cat='bat --paging=never'

# Editor
alias vim='nvim'
alias v='nvim'

# Git
alias g='git'
alias lg='lazygit'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'

# Open yazi, and stay in the folder it was in when you quit.
y() {
  local cwd_file cwd
  cwd_file="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$cwd_file"
  cwd="$(cat -- "$cwd_file")"
  if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$cwd_file"
}

# Posting (HTTP client), able to tell Ctrl+Shift+P (commands) from Ctrl+P (find a request).
# Inside tmux, both arrive as Ctrl+P unless the program asks tmux for "mode 2" extended keys,
# which Posting doesn't do itself. So ask for it while Posting runs, and switch back after.
posting() {
  if [[ -n "$TMUX" ]]; then
    printf '\e[>4;2m'
  fi
  command posting "$@"
  local exit_code=$?
  if [[ -n "$TMUX" ]]; then
    printf '\e[>4m'
  fi
  return $exit_code
}
