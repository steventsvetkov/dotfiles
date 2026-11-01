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
