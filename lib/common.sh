# Shared helpers for every script in the repo.
# This file only defines variables and functions; sourcing it changes nothing.
# Nothing here depends on the operating system: OS-specific code lives in os/<name>/.
#
# Must work with bash 3.2, the version macOS ships with.

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# Existing files that a symlink would replace are moved here instead of deleted.
BACKUP_DIR="$HOME/.local/state/dotfiles/backup/$(date +%Y-%m-%d_%H-%M-%S)"

# The OS this machine was installed as: a symlink to one of the folders in $DOTFILES/os.
# Set by the installer, read by the `dotfiles` command.
OS_LINK="$HOME/.config/dotfiles/os"

# Layers are private dotfiles repos cloned next to this one, as ~/.dotfiles-<name>: one for
# work (~/.dotfiles-cubby), and later others for side projects or clients. Each adds its own
# packages and configs on top of this repo. See "Layers" in AGENTS.md.
LAYER_PREFIX="$HOME/.dotfiles-"

# The active theme: a symlink to one of the folders in $DOTFILES/themes.
THEME_LINK="$HOME/.config/dotfiles/theme"
DEFAULT_THEME="catppuccin-charcoal"


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

info() { printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }


# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

# Makes $target a symlink to $source.
# Does nothing if the link is already correct, so it is safe to call repeatedly.
link_file() {
  local source="$1"
  local target="$2"

  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    local backup="$BACKUP_DIR/${target#"$HOME"/}"
    mkdir -p "$(dirname "$backup")"
    mv "$target" "$backup"
    warn "Moved existing $target to $backup"
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  ok "Linked ${target/#$HOME/~}"
}

# Links every file in a home folder of the repo (shared/home, os/<name>/home)
# to the same path under $HOME. Files are linked one by one, not whole folders,
# so files that apps create next to our configs stay out of the repo.
link_home_folder() {
  local home_folder="$1"

  local file
  while IFS= read -r file; do
    link_file "$file" "$HOME/${file#"$home_folder"/}"
  done < <(find "$home_folder" -type f ! -name '.DS_Store')
}

# Removes symlinks that point into the repo (or a layer) at a file that no longer exists,
# e.g. after a config was deleted or moved in the repo.
remove_stale_links() {
  local link target
  # With -L, find reports only the symlinks it cannot follow, i.e. broken ones.
  while IFS= read -r link; do
    target="$(readlink "$link")"
    if [[ "$target" == "$DOTFILES"/* || "$target" == "$LAYER_PREFIX"* ]]; then
      rm "$link"
      ok "Removed stale link ${link/#$HOME/~}"
    fi
  done < <(
    find -L "$HOME" -maxdepth 1 -type l 2>/dev/null
    find -L "$HOME/.config" "$HOME/.local/bin" -type l 2>/dev/null
  )
}

# Prints the folder of every layer on this machine, one per line.
list_layers() {
  local layer
  for layer in "$LAYER_PREFIX"*/; do
    if [[ -d "$layer" ]]; then
      echo "${layer%/}"
    fi
  done
}

# Prints a layer's name: "cubby" for ~/.dotfiles-cubby.
layer_name() {
  local layer="$1"
  echo "${layer#"$LAYER_PREFIX"}"
}

# Moves a file or folder from its old place in ~ to its XDG location.
# Skips it if there is nothing to move. If both exist, leaves both for a person to merge.
move_to_xdg() {
  local old="$1"
  local new="$2"

  if [[ ! -e "$old" ]]; then
    return 0
  fi

  if [[ -e "$new" ]]; then
    warn "Both ${old/#$HOME/~} and ${new/#$HOME/~} exist. Merge them by hand, then delete the old one."
    return 0
  fi

  mkdir -p "$(dirname "$new")"
  mv "$old" "$new"
  ok "Moved ${old/#$HOME/~} to ${new/#$HOME/~}"
}

# Appends a line to a file, using sudo only when we cannot write the file ourselves
# (system files like /etc/shells).
append_line() {
  local file="$1"
  local line="$2"

  if [[ -w "$file" ]] || [[ ! -e "$file" && -w "$(dirname "$file")" ]]; then
    echo "$line" >> "$file"
  else
    echo "$line" | sudo tee -a "$file" >/dev/null
  fi
}

# Prints the package names in a list file: one per line, # starts a comment.
read_package_list() {
  local list_file="$1"
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$list_file" | grep -v '^$'
}


# ---------------------------------------------------------------------------
# Themes
# ---------------------------------------------------------------------------

# Prints the name of the active theme, or nothing if none is set.
current_theme() {
  if [[ -L "$THEME_LINK" ]]; then
    basename "$(readlink "$THEME_LINK")"
  fi
}

# Prints the names of all available themes, one per line.
list_themes() {
  local dir
  for dir in "$DOTFILES"/themes/*/; do
    basename "$dir"
  done
}

# Activates a theme by pointing $THEME_LINK at its folder.
# Each tool reads its colors through $THEME_LINK, so this one link switches them all.
set_theme() {
  local name="$1"
  local theme_dir="$DOTFILES/themes/$name"
  [[ -d "$theme_dir" ]] || die "Unknown theme '$name'. Available: $(list_themes | tr '\n' ' ')"

  mkdir -p "$(dirname "$THEME_LINK")"
  ln -sfn "$theme_dir" "$THEME_LINK"

  # Where each tool looks for its theme file. These links never change;
  # they always point through $THEME_LINK at the active theme.
  link_file "$THEME_LINK/ghostty"     "$HOME/.config/ghostty/themes/current"
  link_file "$THEME_LINK/bat.tmTheme" "$HOME/.config/bat/themes/current.tmTheme"
  link_file "$THEME_LINK/btop.theme"  "$HOME/.config/btop/themes/current.theme"
  link_file "$THEME_LINK/posting.yaml" "$HOME/.local/share/posting/themes/current.yaml"
  link_file "$THEME_LINK/posting-production.yaml" "$HOME/.local/share/posting/themes/current-production.yaml"

  # bat (and delta, which uses bat's themes) only sees new themes after a cache rebuild.
  if command -v bat >/dev/null; then
    bat cache --build >/dev/null
  fi

  ok "Theme: $name"
}
