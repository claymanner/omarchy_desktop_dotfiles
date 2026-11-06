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
- **Two model budgets, use both.** Clayton has a Claude "300" plan and a Codex "150" plan (his words, 2026-10-16), so plenty of
  capacity on both. Spread swarms across them: Claude workflows/subagents for design, review, and
  integration; `codex exec ... </dev/null` (non-interactive; without `</dev/null` a backgrounded run hangs on "Reading additional input from stdin") for
  parallel implementation slices, second-opinion reviews, and image generation (Codex's built-in
  `image_gen` is better at UI mockups). Give each agent a self-contained brief and a contract; never
  have both edit the same files at once.
- **Still state real costs** (tokens, review load, prod risk) and still put dangerous steps behind
  Clayton's approval. Speed doesn't change the safety rules.


## Never lose what Clayton adds mid-turn

When Clayton adds a feature, changes direction or makes a decision while you're working, record it **in the same turn,
before more building**:
- in the project's plan or scope doc (its decisions section), and in the build manifest if it changes a slice;
- as a GitHub issue in the project's repo, labelled `from-clayton`, with his words quoted.

Then adjust any running work it affects. "Make as many tickets as needed" means: file them, one per slice, decision and finding.

## Clayton talks in whole thoughts: you split them, not him

Clayton usually dictates one long message into whichever chat is in front of him, mixing this task with other work
(his words, 2026-11-06: "annoying to constantly have to be thinking about what is what"). Never ask him to go
somewhere else or to re-send part of it. Split it yourself, in the same turn:
- **Parts that belong to your current task:** do them.
- **Everything else** (new build work, another customer or ticket, another repo, a reminder): hand it to HQ with
  `to-hq "<his words, quoted> + the context you have (site, ids, links, what you found)"`. HQ files the issue and
  starts the right workspace. On the workstation or anywhere `to-hq` doesn't exist, file the issue yourself
  (`gh issue create … --label from-clayton`) instead.
- End your reply with one line per handed-off part ("→ HQ: LTE-active alerting"), so he sees nothing was dropped.
- **Never type into another chat with `orca terminal send`.** Clayton may be mid-sentence there, and his half-typed
  text gets merged with yours and submitted (2026-11-06). To message another agent, use `orca-safe-send <handle> <text>`,
  which waits for an empty input box. To hand work to HQ, use `to-hq`, which never touches his HQ chat.

## Asks for Clayton go in the queue, never only in prose

Clayton misses questions and to-dos that are buried in a reply, especially once more messages follow
(his words, 2026-11-05: "it gets buried in the replies and then missed completely"). So **every**
decision, piece of info or action you need from him goes in a closing block of your reply, **numbered**, one per line,
so he can answer by number ("1: yes, after hours. 2: change it"):

```
NEEDS-CLAYTON
1. [Decision] Riley deploy window: tonight 22:00 or Sat AM? (rec: tonight) — blocks #1575
2. [Info] Which Bell circuit ID is the Toronto Bail copper?
3. [Action] Put the Ship24 API key in Vaultwarden as `patchbay/ship24`
```

- On CT 114 `dev`, a Stop hook (`/usr/local/bin/clayton-ask hook`) files each line as a GitHub issue in
  the current repo, labelled `ask:clayton` and assigned to him, deduped. It also puts the unread dot on
  the Orca card. Anywhere else (Codex, workstation), or for an ask outside a reply, run
  `clayton-ask file --kind Decision|Info|Action --title "..." [--body "..."] [--repo owner/repo]` yourself.
- Number the lines from 1 in every reply. When he answers "2: …", act on item 2 of your last NEEDS-CLAYTON block.
- **Only ask for what Clayton can act on right now** (his words, 2026-11-06: "it should only present me with action
  to do when i can actually do it"):
  - Never hand him a command or step you can run yourself. Ask for approval instead, as a `[Decision]`, and do it.
  - If a step must wait for something (a deploy, a merge, a customer reply), and you can do it then: ask for approval
    now ("OK if I turn on X once #1949 deploys? (rec: yes)") and do it yourself when the time comes.
  - If it truly needs *his* hands but only after something else happens, tag it with what it waits for:
    `2. [Action, after patchbay#1949] …`. It's parked (no push, no Needs you) and reaches him automatically once that
    PR/issue closes (`clayton-ask promote` timer on CT 114, every 10 min). From the CLI: `clayton-ask file … --after <repo>#<n>`.
- Make each line self-contained: what you need, the options with your recommendation, and what it blocks.
- When he asks "anything left?", answer about **your current task**. Don't re-list older asks; they're in his HQ
  queue. At most say "N older asks are waiting in HQ".
- Don't keep asking the same thing in prose. Once an ask is filed, refer to its issue.
- When Clayton answers (in chat or on the issue), act on it and close the issue with a comment.
- The full queue: `clayton-ask list`. Design: vault `Orca Playbook.md` → Rule 6.
