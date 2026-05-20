# Global Claude Code instructions (Clayton's machine)

## Shared knowledge layer — ALWAYS check this first

Clayton maintains a canonical app/service runbook at:

**`/home/cmannerow/Documents/ObsidianVault/Obsidian Vault/30 Resources/Apps/`**

This directory is synced via Nextcloud across every machine he uses (workstation, laptop, future machines). Every AI tool (you, Codex, [[Jarvis]], future tools) reads from and writes to it. It's the SINGLE SOURCE OF TRUTH for:

- What each app is (Pile, Aftercalls, Conduit, FsPBX, Jarvis, Proxmox, Home Assistant, UniFi, Telnyx, Zoho One, Nextcloud, Immich, GitHub, OpenAI, Vaultwarden, pbx-support-agent, …)
- How to access it (URLs, ZeroTier IPs, SSH aliases, keys, ports, auth model)
- What credentials it uses and where they live (Vaultwarden references — never plaintext in the notes)
- What top voice/CC commands fit it
- Current state and open work
- Known gotchas

### When to read it

- ANY question about app access, IPs, ports, credentials, deploy paths, repo locations
- Before answering "where is X", "how do I get into Y", "what's the API for Z"
- Before guessing or asking Clayton — check the index first

Start with `INDEX.md` in that directory. Each app has its own `.md` (e.g. `Pile.md`, `Conduit.md`). Cross-references use `[[NoteName]]` wikilinks.

### When to update it

If you learn something durable about any app — new IP, new auth method, new feature, new gotcha, a deploy or migration — UPDATE the relevant note in this directory. Don't keep it in your private per-project memory only. The format is in `_TEMPLATE.md`.

**Update what:**
- New URL, IP, port, container name, SSH path
- New auth model or token format
- New top-level command/feature worth knowing
- A bug, gotcha, or surprise that future agents would repeat
- Material change to the app's stack or hosting

**Don't update with:**
- Transient state (current disk usage, current CPU load)
- Conversation-specific context
- Things derivable from `git log` / `kubectl get` / etc.

**How:**
1. Read the existing note. Don't duplicate sections.
2. Edit in place. Save.
3. Tell Clayton in your reply what you updated.
4. If creating a new app note, copy `_TEMPLATE.md` and add a link to `INDEX.md` under the right category.

This makes every future session — yours, mine, Jarvis's, Codex's — start with a much better picture of Clayton's infrastructure.

## Repo-local CLAUDE.md still wins

When you're operating inside a specific repo, its own `CLAUDE.md` is authoritative for repo-specific rules (hard rules, code conventions, etc.). The vault is for cross-repo / cross-tool runbook context. Both apply.

## Per-project Jarvis memory still applies

The fspbx-project memory at `~/.claude/projects/-home-cmannerow-Nextcloud-Documents-programming-fspbx/memory/` is still active and gets auto-loaded. Use it for fspbx-specific things; promote durable cross-tool facts to the vault.

## Dotfiles + Claude config (cross-machine sync)

Clayton's configs are stowed from `~/omarchy_desktop_dotfiles` (a git repo at `claymanner/omarchy_desktop_dotfiles`) so his laptop + desktop stay in sync. Current stow packages:

| Package | Stows into | Contents |
|---|---|---|
| `claude-config` | `~/.claude/CLAUDE.md`, `~/.claude/settings.json` | This file + global Claude settings. |
| `claude-skills` | `~/.claude/skills/<name>/` | Reusable Claude skills (currently: `inbox-triage`). |
| `bashrc` | `~/.bashrc` | Bash shell config. |
| `zsh` | `~/.zshrc` | Zsh shell config. |
| `tmux` | `~/.tmux.conf`, `~/.config/tmux/` | Tmux config + pane/window label scripts. |
| `nvim` | `~/.config/nvim/` | Neovim config (lua-based). |
| `ghostty` | `~/.config/ghostty/config` | Ghostty terminal config. |
| `walker` | `~/.config/walker/config.toml` | Walker launcher config. |
| `waybar` | `~/.config/waybar/` | Waybar config, style.css, and scripts (e.g. `weather.sh`). |
| `bindings` | `~/.config/hypr/bindings.conf` | Hyprland keybindings. |
| `hyprenv` | `~/.config/hypr/envs.conf` | Hyprland environment variables. |
| `hypridle` | `~/.config/hypr/hypridle.conf` | Hyprland idle config. |
| `hyprmonitors` | `~/.config/hypr/monitors.conf` | Hyprland monitor layout (per-machine — be careful). |
| `xcompose` | `~/.XCompose` | X compose-key bindings. |
| `voxtype` | `~/.local/bin/voxtype-{paste-watcher,smart-paste}`, `~/.config/systemd/user/voxtype-paste-watcher.service` | Smart-paste watcher: types ctrl+v (or shift+insert in terminals) after voxtype finishes transcribing. |
| `scripts` | (not stowed into HOME — repo-local) | `bootstrap.sh`, `sync.sh` for setup/sync on new machines. |
| `share` | (not stowed into HOME — repo-local) | `systemd/dotfiles-sync.{service,timer}` units. |

**Note on `hyprmonitors`:** monitor configs differ between desktop and laptop. Both machines currently share the same file, but if it diverges, this package may need to be split or made machine-local.

**Per-machine state under `~/.claude/`** — never commit: `.credentials.json`, `history.jsonl`, `sessions/`, `tasks/`, `cache/`, `agent-state/`, `settings.local.json`, `projects/*/memory/*` (see "Where memories live" below).

### When you (Claude) should update this dotfiles repo

- **Built a new reusable skill** → put it under `~/omarchy_desktop_dotfiles/claude-skills/.claude/skills/<name>/`, stow, commit, push.
- **Edited this file (`CLAUDE.md`)** → just save; the symlink means the repo file is updated. Commit + push.
- **Changed `settings.json`** → same: symlinked, repo is updated. Commit + push.
- **Bumped an existing skill** (new logic, new template) → edit in place, commit + push. The change propagates to the laptop next `git pull && stow -R claude-skills`.

### How to update + push (canonical pattern)

```bash
cd ~/omarchy_desktop_dotfiles
git add claude-config/ claude-skills/        # or whichever package you changed
git diff --cached --stat
git commit -m "<short summary of the change>"
git push origin main
```

If you also stowed a NEW package, run `stow --target="$HOME" <pkg>` from the repo root first to symlink it into place.

### When new skills land — name + describe well

Skills are auto-loaded; the `description:` frontmatter is what triggers selection in future sessions. Make it:
- specific about WHEN to use (trigger phrases)
- specific about WHEN to skip (don't fire on adjacent work)
- ~80-200 words; longer than this gets truncated in the runtime catalog.

### Where memories live (NOT yet dotfiled, deliberate)

`~/.claude/projects/*/memory/*.md` files are auto-managed by the memory system. They're great per-user, but most are project-specific paths that don't translate to the laptop one-to-one (the project hash in the path encodes the full filesystem location). Treat them as machine-local for now. If you find yourself adding a memory that's clearly cross-machine (a vault reference, a global preference, etc.), mention to Clayton — we may eventually carve a `claude-memory` package for the universal slice.

### When you make changes that affect both desktop AND laptop

Both machines run the same stow setup. After committing on this machine, remind Clayton (or do via SSH if you have access) to:
```bash
cd ~/omarchy_desktop_dotfiles && git pull && stow -R claude-config claude-skills
```
on the other machine to pick up the changes.
