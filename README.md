<div align="center">

# dotfiles

**A personal computer should be truly personal.**<br>
Shaped around how you like to work, what you need and what you love,<br>
and a joy to use every single day.

<br>

![macOS](https://img.shields.io/badge/macOS-1c1c1c?style=for-the-badge&logo=apple&logoColor=cdd6f4)
![Ubuntu](https://img.shields.io/badge/Ubuntu_&_WSL-1c1c1c?style=for-the-badge&logo=ubuntu&logoColor=fab387)
![Arch](https://img.shields.io/badge/Arch_·_Omarchy-1c1c1c?style=for-the-badge&logo=archlinux&logoColor=89b4fa)

</div>

<br>

## What's inside

|              |                                                                    |
|--------------|--------------------------------------------------------------------|
| **Shell**    | zsh with starship, fzf, zoxide, eza, bat and friends               |
| **Terminal** | Ghostty, tmux with sesh, workmux for one worktree per branch       |
| **Editors**  | Neovim, VS Code                                                     |
| **Git**      | lazygit, delta diffs, commits signed with an SSH key               |
| **AI**       | Claude Code and OpenCode, with MCP servers and shared instructions |
| **macOS**    | AeroSpace tiling, SketchyBar, Karabiner, Zen                       |
| **Runtimes** | mise for node, python and anything Homebrew doesn't have           |

Every tool shares one theme: [Catppuccin Charcoal](themes/catppuccin-charcoal),
Catppuccin Mocha's colors on neutral grey instead of purple.

## Install

Get git first: `xcode-select --install` on macOS, `sudo apt install git` on Ubuntu,
`sudo pacman -S git` on Arch. Then:

```sh
git clone https://github.com/steventsvetkov/dotfiles ~/.dotfiles
~/.dotfiles/install.sh
```

The installer works out which system it is on and sets everything up. Run it as often
as you like: a second run changes nothing.

Then sign in, once:

```sh
gh auth login          # GitHub
opencode auth login    # model providers for OpenCode
workmux setup          # agent status in tmux
```

## Everyday

```
dotfiles pull       get changes from another machine
dotfiles push       commit and push this machine's changes
dotfiles status     see what's not pushed yet
dotfiles upgrade    upgrade everything: packages, apps, runtimes, plugins
dotfiles theme      switch the color theme
dotfiles edit       open this repo (or a layer: dotfiles edit cubby) in your editor
```

## The rules it lives by

- **Same keys everywhere.** Ctrl copies and pastes like on Linux; Cmd drives the window manager.
- **One theme.** Change it once, every app follows.
- **A clean home folder.** Settings live in `~/.config`, never loose in `~`.
- **Safe to rerun.** Nothing is overwritten without a backup.

Machine-specific settings and secrets stay out of the repo, in `~/.config/zsh/local.zsh`
and `~/.config/git/local`.

## Layers

Work and client setups live in their own private repos, cloned next to this one as
`~/.dotfiles-<name>`. Each adds packages and configs on top of everything here, and
`dotfiles install` picks it up automatically:

```sh
git clone git@github.com:steventsvetkov/dotfiles-cubby ~/.dotfiles-cubby   # private
dotfiles install
```

How it all fits together is in [AGENTS.md](AGENTS.md), written for AI agents but readable by anyone.

<br>

<p align="center">
  <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/footers/gray0_ctp_on_line.svg" alt="">
</p>
