# upgrade-aged

Vendored from https://github.com/mbologna/upgrade-aged (MIT, see LICENSE), commit
`15f5be21e5c3240b1b46841002111570a5a5dac0`. These scripts upgrade Homebrew packages, mise
tools, uv tools, VS Code extensions and Mac App Store apps only once a release is old
enough (`MIN_AGE_DAYS`, set to 3 in `lib/steps.sh`), unless the installed version has a known vulnerability.
Homebrew has no such setting itself. `dotfiles upgrade` runs them (see `upgrade_aged_packages`
in `lib/steps.sh`).

Changes from upstream:
- `lib/brew-updated-casks.sh`: this repo's self-updating casks, plus any a layer lists in
  `~/.config/upgrade-aged/casks`.
- `renovate.json` and the upstream README are left out.

To update, copy the new files over this folder and put the changes above back.
