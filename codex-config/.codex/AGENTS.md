# Global Codex instructions (Clayton's machines)

Shared runbook: `/home/cmannerow/Documents/ObsidianVault/Obsidian Vault/30 Resources/Apps/` (start at INDEX.md).
The full cross-tool rules live in the Claude config (`claude-config/.claude/CLAUDE.md` in claymanner/omarchy_desktop_dotfiles):
never run heavy workloads (test suites, installs, containers) on the workstation, so use GitHub Actions or the Proxmox CT 114 `dev` box;
use `pkexec`, never `sudo`; production deploys only from committed code.

## Plan and estimate for agent-swarm speed, not for a solo human

**Clayton has had to correct this many times, in every repo. Don't make him say it again.**
The builder is you (Codex) and Claude running parallel agents, not Clayton typing code. Writing the
code is the cheap, fast part. Never size, phase or sequence work as though one person codes it.

- **No human dev-day or week estimates for building.** Don't write "≈12 weeks", "6-8 dev-days" or
  "MVP first because it's smaller to build". Estimate in agent waves and wall-clock hours, and say
  roughly how many parallel agents each wave uses.
- **Don't shrink scope to save build effort.** Defer a feature only for a real reason:
  - it depends on facts we don't have yet (a live API probe, a pilot's result, Clayton's decision);
  - it's a risk gate (prod deploy, disclosure, money, customer-facing sends);
  - the people who'll use it need time to adopt it.
  Say which reason applies. "Too much work for one builder" is never one.
- **Phases follow what actually limits the pace:** Clayton's review and approval bandwidth, live
  verification against real systems, deploy and safety gates, data that only real use produces, and
  people learning a new tool.
- **Plan builds as swarms.** Contracts and interfaces first (schemas, OpenAPI, shared types), so
  agents can then work on separate slices in parallel worktrees. Verify each slice adversarially, put
  test suites in CI (never the workstation), and make one integration pass.
- **Two model budgets, use both.** Clayton has Claude Max (the $200 tier, "300 plan") and Codex Pro-level
  capacity ("150"). Spread swarms across them: Claude workflows/subagents for design, review, and
  integration; `codex exec` (non-interactive, works headless on CT 114 and the workstation) for
  parallel implementation slices, second-opinion reviews, and image generation (Codex's built-in
  `image_gen` is better at UI mockups). Give each agent a self-contained brief and a contract; never
  have both edit the same files at once.
- **Still state real costs** (tokens, review load, prod risk) and still put dangerous steps behind
  Clayton's approval. Speed doesn't change the safety rules.

