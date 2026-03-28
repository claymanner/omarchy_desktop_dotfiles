# omarchy_desktop_dotfiles

Personal Omarchy desktop dotfiles, intended to be symlinked into `$HOME`.

## Syncing

This repo is set up in a `stow`-friendly layout:

- `bashrc/.bashrc` -> `~/.bashrc`
- `tmux/.tmux.conf` -> `~/.tmux.conf`
- `tmux/.config/tmux/tmux.conf` -> `~/.config/tmux/tmux.conf`
- `zsh/.zshrc` -> `~/.zshrc`
- `xcompose/.XCompose` -> `~/.XCompose`

Example:

```bash
cd ~/omarchy_desktop_dotfiles
stow bashrc tmux zsh xcompose
```

## What is customized

### Bashrc

- Starts or attaches tmux on login.
- Sets tmux SSH pane titles to the connected host.

### Tmux

- Uses `C-f` as the prefix.
- Tweaks appearance and window management.
- Shows SSH targets by hostname instead of a generic `ssh`.
- Shows app names like `codex` for non-shell panes instead of collapsing everything to the current directory.
- Resolves Node-wrapped CLIs like Codex from the pane process tree.

### Zsh

- Mirrors the tmux auto-attach and SSH pane-title behavior from Bash.

### Hyprenv

- Changes the default screenshot file location to Nextcloud.

### Ghostty

- Changes the default font size.

### Neovim

- Adjusts relative line appearance.
- Changes Blink completion so `Enter` does not accept the completion and `C-y` does.

### Waybar

- Shows the date in the main clock.

### XCompose

- Adds name and email shortcuts on `Caps` + `Space`.
