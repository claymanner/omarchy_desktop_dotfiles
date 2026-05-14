# omarchy_desktop_dotfiles

Personal Omarchy dotfiles, intended to be symlinked into `$HOME` via GNU stow.

## Fresh-machine bootstrap

After installing Omarchy on a new machine:

```bash
git clone https://github.com/claymanner/omarchy_desktop_dotfiles ~/omarchy_desktop_dotfiles
cd ~/omarchy_desktop_dotfiles && bash scripts/bootstrap.sh
```

This will:

1. Install pacman + AUR packages from `packages.txt` (uses `yay`, ~227 packages)
2. Stow every config package (skipping `hyprmonitors` — that's desktop-specific; stow manually if wanted)
3. Clone Jarvis to `~/code/jarvis` and run its installer (venv, systemd unit, Hyprland binding)
4. Install Voxtype if available
5. Enable the dotfiles auto-sync timer

Manual steps after the script prints `==> bootstrap complete`:

- `bw config server https://bitwarden.mannerow.net && bw login clayton@mannerow.net`
- `bash ~/code/jarvis/scripts/restore-secrets.sh` (pulls Jarvis tokens + SSH deploy keys from Vaultwarden)
- `systemctl --user enable --now jarvisd && hyprctl reload`
- Pair Syncthing / Nextcloud / cloudflared via their web UIs (device IDs are per-machine)
- Configure `~/.config/hypr/monitors.conf` for this box

The bootstrap is idempotent — re-run after edits without breaking anything.

## Auto-sync between machines

A user-level systemd timer pulls this repo every 15 min so commits pushed from
one machine propagate to the others without manual `git pull`.

Enable on a new machine (the bootstrap does this automatically):

```bash
mkdir -p ~/.config/systemd/user
install -m 0644 share/systemd/dotfiles-sync.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-sync.timer
```

Status / logs:

```bash
systemctl --user list-timers dotfiles-sync.timer
journalctl --user -u dotfiles-sync.service
```

It runs `git pull --ff-only` only — no auto-commit, no auto-stow. Push from any
machine when you're ready; the others pick it up within 15 min. If you add a
new stow package, run `stow <pkg>` manually after the next pull.

Refresh the package snapshot when you've installed something new and want it
in the bootstrap:

```bash
pacman -Qqe > packages.txt
git commit -am "refresh packages.txt"
```

## Stow layout

```bash
cd ~/omarchy_desktop_dotfiles
stow bashrc bindings ghostty hyprenv hypridle nvim tmux walker waybar xcompose zsh
# stow hyprmonitors    # desktop only
```

Each top-level directory is a stow package whose contents mirror the target
path under `$HOME`:

- `bashrc/.bashrc` → `~/.bashrc`
- `tmux/.tmux.conf` → `~/.tmux.conf`
- `tmux/.config/tmux/tmux.conf` → `~/.config/tmux/tmux.conf`
- `tmux/.config/tmux/cheatsheet.txt` → `~/.config/tmux/cheatsheet.txt`
- `tmux/.config/tmux/scripts/` → `~/.config/tmux/scripts/`
- `zsh/.zshrc` → `~/.zshrc`
- `xcompose/.XCompose` → `~/.XCompose`
- `hypridle/.config/hypr/hypridle.conf` → `~/.config/hypr/hypridle.conf`
- ... etc.

## What is customized

### Bashrc / Zsh

- Starts or attaches tmux on login.
- Sets tmux SSH pane titles to the connected host.

### Tmux

- Prefix is `C-f`.
- Clean status bar: session name on the left, `PREFIX` / SSH host badges on
  the right.
- Solid block highlight on the active window; agent state indicators (`!`
  red = input wanted, `●` yellow = waiting, `▶` blue = working) sit inside
  that highlight.
- `C-f ?` opens a cheatsheet popup of common keys.
- Shows app names like `claude` / `codex` for non-shell panes via the
  pane-label script — useful when juggling agents across windows.

### Bindings (Hyprland)

- `SUPER + SHIFT + J` → toggle a Jarvis voice session.
- `INSERT` (no modifier) → toggle Voxtype dictation (Glove80 thumb-key
  friendly).
- `SUPER + V` → sends `Shift+Insert` (terminal paste). Use plain `Ctrl+V`
  inside browsers and most GUI apps.
- `SUPER + ALT + RETURN` → new floating terminal that drops you into tmux.

### Hyprenv

- Redirects screenshots into Nextcloud.

### Hypridle

- DPMS screen-off disabled (this hardware doesn't recover cleanly).
- Lock + screensaver behavior is kept.

### Ghostty

- Larger default font, async-backend tweak for Hyprland smoothness.

### Neovim

- Relative line numbers, blink completion uses `C-y` to accept (not `Enter`).

### Waybar

- Date + clock module.
- Weather pinned to East Oro in °C.
- Voxtype + idle-indicator + screenrecording-indicator modules in the center.
- Tray is expanded by default (no collapse).

### XCompose

- `Caps + Space` shortcuts for name + email.
