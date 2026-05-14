#!/usr/bin/env bash
# Pull latest dotfiles. Safe to run on any schedule — fast-forward only, no
# auto-commit. New files won't be symlinked automatically; run `stow <pkg>`
# manually after a pull if you see new packages.
set -euo pipefail

REPO="${DOTFILES_REPO:-$HOME/omarchy_desktop_dotfiles}"

cd "$REPO"
# Only pull if we're on a branch tracking a remote
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git fetch --quiet
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse '@{u}')
    if [[ "$LOCAL" != "$REMOTE" ]]; then
        git pull --ff-only --quiet || {
            echo "dotfiles sync: pull failed (possible conflict)" >&2
            exit 1
        }
        echo "dotfiles sync: pulled new commits"
    fi
fi
