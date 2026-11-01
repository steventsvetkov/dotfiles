# Global instructions for AI coding agents

Read by OpenCode (`~/.config/opencode/AGENTS.md`) and by Claude Code, whose global
`CLAUDE.md` imports this file. Kept in the dotfiles repo: `~/.dotfiles/shared/home/.config/opencode/AGENTS.md`.

## Code

- Write clean, plain, readable code that a person understands at a glance.
  No clever tricks, no one-liners that need a second read, no unnecessary abstraction.
- Match the style, naming and comment density of the surrounding code.
- Comments explain *why*, not *what*.

## This machine

- All configuration of this machine lives in the dotfiles repo at `~/.dotfiles`.
  Never edit a config file directly in `$HOME`: change it in the repo. Read
  `~/.dotfiles/AGENTS.md` before changing anything there.
- Keep `~` free of config files: tools keep their files in `~/.config`,
  `~/.local/share`, `~/.local/state` and `~/.cache` (XDG).
- Install software with Homebrew where possible (`~/.dotfiles/shared/Brewfile`, or
  `~/.dotfiles/os/macos/Brewfile` for Mac apps), language runtimes with mise.
