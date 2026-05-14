#!/usr/bin/env bash
# Bootstrap a fresh Omarchy machine from this dotfiles repo.
#
# Assumes Omarchy is already installed (this script does NOT install Omarchy
# itself — start with the standard Omarchy installer first).
#
# Usage:
#   git clone https://github.com/claymanner/omarchy_desktop_dotfiles ~/omarchy_desktop_dotfiles
#   cd ~/omarchy_desktop_dotfiles && bash scripts/bootstrap.sh
#
# Re-runnable. Each step skips work that's already done.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKIP_STOW="${SKIP_STOW:-hyprmonitors}"   # comma-separated packages to skip

log() { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! \033[0m%s\n" "$*" >&2; }

# 1. Install packages from snapshot
log "Installing packages from packages.txt (this may take a while)..."
if [[ -f "$REPO/packages.txt" ]]; then
    if ! command -v yay >/dev/null; then
        warn "yay not installed — Omarchy should provide it. Install manually first."
        exit 1
    fi
    # --needed skips already-installed; --ask 4 handles conflicts non-interactively
    yay -S --needed --noconfirm --ask 4 - < "$REPO/packages.txt" || \
        warn "Some packages failed to install — review output above"
else
    warn "packages.txt missing, skipping package install"
fi

# 2. Stow all packages except those listed in SKIP_STOW
log "Stowing config packages..."
cd "$REPO"
IFS=',' read -ra SKIPS <<< "$SKIP_STOW"
for pkg in */; do
    pkg="${pkg%/}"
    # Skip non-stow directories
    case "$pkg" in
        scripts|share|.git) continue ;;
    esac
    skip=false
    for s in "${SKIPS[@]}"; do
        [[ "$pkg" == "$s" ]] && skip=true && break
    done
    if $skip; then
        log "  skip: $pkg"
        continue
    fi
    log "  stow: $pkg"
    stow -v "$pkg" 2>&1 | sed 's/^/      /' || warn "stow $pkg had conflicts — resolve manually"
done

# 3. Jarvis
JARVIS_DIR="$HOME/code/jarvis"
if [[ ! -e "$JARVIS_DIR" ]]; then
    log "Cloning Jarvis..."
    mkdir -p "$HOME/code"
    git clone https://github.com/smartpbx/jarvis "$JARVIS_DIR"
fi
if [[ ! -d "$JARVIS_DIR/.venv" ]]; then
    log "Running Jarvis installer..."
    bash "$JARVIS_DIR/scripts/install.sh"
fi

# 4. Voxtype (omarchy provides the installer command)
if ! command -v voxtype >/dev/null; then
    log "Installing Voxtype..."
    if command -v omarchy-voxtype-install >/dev/null; then
        omarchy-voxtype-install || warn "voxtype install failed"
    else
        warn "omarchy-voxtype-install not found — install manually later"
    fi
fi

# 5. Auto-sync timer
log "Installing dotfiles auto-sync systemd timer..."
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
install -m 0644 "$REPO/share/systemd/dotfiles-sync.service" "$SYSTEMD_USER_DIR/"
install -m 0644 "$REPO/share/systemd/dotfiles-sync.timer" "$SYSTEMD_USER_DIR/"
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-sync.timer

cat <<EOF

\033[1;32m==> bootstrap complete\033[0m

Manual steps that need human attention:

  1. Bitwarden CLI is installed via packages.txt. Log in and unlock so the
     Jarvis secrets restore can run:

       bw config server https://bitwarden.mannerow.net
       bw login clayton@mannerow.net
       bash ~/code/jarvis/scripts/restore-secrets.sh

  2. Start the Jarvis daemon (after secrets are restored):

       systemctl --user enable --now jarvisd
       hyprctl reload

  3. If you use Syncthing / Nextcloud / cloudflared, pair them via their web
     UIs — device IDs are per-machine and can't be cloned.

  4. Per-machine monitor layout: stow 'hyprmonitors' was skipped by default
     (desktop-specific). Configure ~/.config/hypr/monitors.conf for this box,
     or stow it manually with: stow hyprmonitors

EOF
