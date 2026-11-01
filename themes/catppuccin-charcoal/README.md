# Catppuccin Charcoal

[Catppuccin Mocha](https://catppuccin.com/palette) with its purple-tinted backgrounds
replaced by neutral greys. Accent and text colors are unchanged.

| Role       | Mocha     | Charcoal  |
|------------|-----------|-----------|
| crust      | `#11111b` | `#0a0a0a` |
| mantle     | `#181825` | `#0c0c0c` |
| base       | `#1e1e2e` | `#101010` |
| surface0   | `#313244` | `#1e1e1e` |
| surface1   | `#45475a` | `#282828` |
| surface2   | `#585b70` | `#323232` |

Two changes to the terminal palette (`ghostty`), compared with official Catppuccin:

- Color 5/13 (magenta) is mauve `#cba6f7` instead of pink, so "purple" in tools is Catppuccin's signature color.
- Color 8 (bright black) is overlay0 `#6c7086`, so dim text such as autosuggestions stays readable on charcoal.

## Files

| File          | Used by                                                        |
|---------------|----------------------------------------------------------------|
| `ghostty`     | Ghostty. Its 16 colors are also used by every tool that sticks to terminal colors (zsh, starship, eza, lazygit, yazi) |
| `fzf`         | fzf                                                            |
| `bat.tmTheme` | bat, and git diffs through delta                               |
| `btop.theme`  | btop                                                           |
| `sketchybar.sh` | SketchyBar (macOS menu bar)                                  |

`bat.tmTheme` and `btop.theme` are the official Catppuccin files with the colors in the
table above swapped. To change the background, replace the hex value in every file here.
