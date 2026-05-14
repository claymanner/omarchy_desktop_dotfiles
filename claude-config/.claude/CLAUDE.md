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
