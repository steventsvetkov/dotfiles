# Dotfiles: instructions for AI agents

This repo is the single source of truth for how Steven's machines are set up:
macOS, WSL (Ubuntu), and Omarchy (Arch + Hyprland).

**Anything you configure on this machine goes in this repo.** Never edit a config file
directly in `$HOME`: put it in the repo (see below) and run `dotfiles install`. Most files
in `$HOME` are symlinks into this repo, so editing them edits the repo anyway.

## How it works

```
install.sh              the only place that checks the OS; runs os/<name>/install.sh
bin/dotfiles            the `dotfiles` command (install, pull, push, status, upgrade, theme, edit)
lib/common.sh           helpers: output, symlinks, themes (no OS logic)
lib/steps.sh            install/upgrade steps shared by all OSes
shared/Brewfile         command line tools for every OS
shared/home/            configs linked into $HOME on every OS
shared/opencode-plugins/  OpenCode plugins, each folder linked whole into ~/.config/opencode/plugins
vendor/                 third-party scripts copied in whole (each has a README with its source and our changes)
themes/<name>/          one folder per color theme
os/<name>/              everything for one OS: macos, ubuntu, arch
  install.sh            the OS's install recipe: a list of steps, in order
  upgrade.sh            run by `dotfiles upgrade`
  before-commit.sh      (optional) run by `dotfiles status` and `push`
  home/                 configs linked into $HOME on this OS only
  Brewfile / *-packages.txt   OS-specific packages (Homebrew casks, apt, pacman)
```

**No OS checks in scripts.** The top-level `install.sh` detects the OS once and runs
`os/<name>/install.sh`. Code for one OS lives in that OS's folder; code shared by all
OSes lives in `lib/` and gets anything that differs (paths, package lists) as arguments.
The installer records the OS as the symlink `~/.config/dotfiles/os`, which the `dotfiles`
command uses to find `upgrade.sh` and `before-commit.sh`. (One exception: WSL is Ubuntu
with a single check in `os/ubuntu/install.sh` to skip desktop apps.)

**Configs:** `shared/home` is linked first, then `os/<name>/home`. Files in `shared/home`
must work on every OS. Where a tool needs OS-specific settings, the shared config
includes a file that each OS's `home/` provides:
- zsh: `.zshenv` sources `os-env.zsh`, `.zprofile` sources `os-profile.zsh` (Homebrew's location)
- Ghostty: `config` includes `os`

**Layers:** this repo is public, so anything specific to an employer, client or side
project lives in a private layer repo cloned next to it as `~/.dotfiles-<name>`. Today
that is `~/.dotfiles-cubby` (work at Cubby, code in `~/source/cubby`). `dotfiles install`
applies every layer after the core, and `pull`, `push` and `status` cover them too.
A layer can have:
- `Brewfile`: packages, installed and upgraded like the core's
- `home/`: configs, linked into `$HOME` file by file
- `install.sh`: any other steps; it can source `$DOTFILES/lib/common.sh`

A layer adds files next to the core's and never replaces one. The core offers hooks for
that: zsh loads `~/.config/zsh/conf.d/*.zsh`, mise reads `~/.config/mise/conf.d/*.toml`,
and git includes a layer's identity for its code folder. Tools that read config from
parent folders (OpenCode, Claude Code's CLAUDE.md) get theirs in the layer's code folder,
e.g. `home/source/cubby/opencode.jsonc`, so work tools only load in work projects.
Each layer has its own AGENTS.md.

**macOS extras:**
- `os/macos/karabiner/` is linked as a whole folder to `~/.config/karabiner`, because
  Karabiner replaces its config file when saving (which breaks a file link).
- Mac app settings in `~/Library/Preferences` cannot be symlinked (macOS replaces the link).
  Apps with an `os/macos/preferences/<bundle-id>.plist` are copied instead: `before-commit.sh`
  exports the current settings into the repo, and `install.sh` imports them only when the
  app has no settings yet on that Mac. Keys listed in `<bundle-id>.ignore` (usage history,
  window sizes) are left out. See `os/macos/settings.sh`.

Things that are not committed:
- `~/.config/git/local`: git name and email for this machine
- `~/.config/zsh/local.zsh`: machine-specific shell settings (interactive shells)
- `~/.config/zsh/local.zshenv`: secrets (API keys, tokens), loaded by every zsh

## Rules

### Code style

- Write clean, plain, readable code that a person can understand at a glance.
  No clever tricks, no one-liners that need a second read, no unnecessary abstraction.
- Small functions with descriptive names. A short comment says *why*, not *what*.
- Match the style of the file you are editing.
- Bash scripts must run on bash 3.2 (the version macOS ships with): no associative
  arrays, `mapfile`, `${var,,}`, or other bash 4+ features. Use `set -euo pipefail`.
- Never check the OS inside a script. Put the code in the right `os/<name>/` folder,
  or pass what differs into a shared step in `lib/steps.sh`.
- Exception: SketchyBar's scripts (`os/macos/home/.config/sketchybar`) use zsh, because
  bash 3.2 cannot read the `$'\u...'` icon escapes. In zsh, never name a variable `status`
  (it is zsh's read-only exit code).
- Use the output helpers in `lib/common.sh` (`info`, `ok`, `warn`, `die`) instead of raw `echo`.

### Idempotency

- Every install script and every step must be safe to run again and again.
  Check the current state before changing anything; a second run should change nothing.
- Never delete user files. `link_file` moves anything it would replace into `~/.local/state/dotfiles/backup/`.
- After a change, test by running `dotfiles install` twice.

### XDG: no config files in ~

- Every tool keeps its files in the XDG folders, never directly in `~`:
  settings in `~/.config`, history and logs in `~/.local/state`, data in
  `~/.local/share`, disposable files in `~/.cache`.
- zsh's config lives in `~/.config/zsh`. The `set_zdotdir` step sets `ZDOTDIR` in the
  system-wide zshenv (`/etc/zshenv` on macOS, `/etc/zsh/zshenv` on Linux), so there is no `~/.zshenv`.
- When adding a tool that writes to `~` by default, point it at an XDG folder
  (usually an environment variable in `shared/home/.config/zsh/.zshenv`) and, if
  it already created files, move them with `move_to_xdg` in `move_old_files_to_xdg` (`lib/steps.sh`).
  [The Arch Wiki XDG page](https://wiki.archlinux.org/title/XDG_Base_Directory) lists the setting for most tools.
- Known exceptions that cannot be moved: `~/.ssh`, and macOS system files
  (`~/Library`, `~/.Trash`, `~/.CFUserTextEncoding`, `.DS_Store`). The repo itself is at `~/.dotfiles`.

### Packages

- `dotfiles upgrade` is age-gated: `upgrade_aged_packages` (`lib/steps.sh`) runs the scripts in
  `vendor/upgrade-aged`, which install a release only once it is 3 days old (unless the installed
  version has a known vulnerability). That covers Homebrew, mise, uv tools, VS Code extensions
  and App Store apps. Never upgrade with a plain `brew upgrade` or `mise upgrade`. A layer lists
  its self-updating casks in `home/.config/upgrade-aged/casks`.
- Install with Homebrew whenever possible. Command line tools for every OS go in
  `shared/Brewfile`; macOS apps and fonts (casks) go in `os/macos/Brewfile`.
- Language runtimes (node, python, go, ...) go through mise: `shared/home/.config/mise/config.toml`.
- On Linux, the system package manager is used only for what cannot or should not come
  from Homebrew: Homebrew's own requirements, zsh (a system shell for logins), and desktop
  apps like Ghostty. They are listed in `os/ubuntu/apt-*.txt` and `os/arch/pacman-packages.txt`.
  Claude Code uses Anthropic's installer there.
- On Omarchy, never edit files in `~/.local/share/omarchy`; override them from `~/.config`
  by adding files to `os/arch/home`.

### Themes

- A tool's colors must come either from the terminal's 16 colors (named colors like
  `blue`, `purple`) or from a file in the active theme folder, read through
  `~/.config/dotfiles/theme`. Never hard-code hex colors in a tool's main config.
- A new themed tool needs a file in **every** theme folder, plus a link in `set_theme`
  in `lib/common.sh` if the tool cannot read the theme path directly.
- The active theme is Catppuccin Charcoal: Catppuccin Mocha accents on neutral
  charcoal backgrounds. Avoid Catppuccin's purple-tinted backgrounds.

### Keyboard (macOS)

Keys work the same way as on Linux/Omarchy:

| Key  | Used for                                                          | Set up in                       |
|------|-------------------------------------------------------------------|---------------------------------|
| Ctrl | App shortcuts (copy, paste, tabs...), like Linux                  | Karabiner, rule "Linux shortcuts" |
| Cmd  | Window manager (Super), with Omarchy's shortcuts                  | Karabiner "Cmd is Super" + AeroSpace |
| Alt  | Terminal (word jumps, fzf Alt+C)                                  | Ghostty `macos-option-as-alt`   |

- Karabiner's Ctrl->Cmd rules skip Ghostty, so Ctrl keeps its terminal meaning there;
  Ghostty uses Linux's Ctrl+Shift+C/V/T/W instead.
- AeroSpace binds only Ctrl+Alt+Cmd combinations. Karabiner turns physical Cmd+<key>
  into those for the window keys. A new window-manager shortcut needs both: the key in
  the "Cmd is Super" rule, and the binding in `aerospace.toml`.
- On the built-in keyboard, Fn and Ctrl are swapped (Karabiner, per-device), so Ctrl is
  in the bottom-left corner like on a PC keyboard.

### Secrets and work details

- Never commit secrets, tokens, or machine-specific identity. Use the uncommitted
  local files listed above.
- This repo is public. Nothing specific to an employer or client goes here: no work
  tools, project names, internal URLs, or examples taken from work. Those go in the
  matching layer (`~/.dotfiles-<name>`).
