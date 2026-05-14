---
name: inbox-triage
description: >
  Use when Clayton wants to clear/triage/sweep his Zoho Mail inbox at
  clayton.mannerow@e-wee.com via the pile triage script. Walks the
  inbox in batches, auto-archives/deletes obvious noise, drafts replies
  into Zoho Drafts, saves customer info to Conduit (with auto-import
  from Zoho CRM), creates pile items for action follow-ups, and
  cleans up duplicates. Triggers: "clear my inbox", "run inbox
  triage", "next batch of emails", "do another batch", "sweep my
  inbox", "process my emails", "triage zoho mail". Skip when the user
  is doing general pile work (item edits, calendar push, schedule) —
  this skill is specifically for the bulk Zoho-mail-to-pile pipeline.
---

# Inbox Triage Skill — Clayton's Zoho Mail → Pile / Conduit / Drafts

End-to-end batch triage of `clayton.mannerow@e-wee.com`. Each batch:

1. Auto-classify N messages via OpenAI (gpt-4o-mini).
2. Auto-execute the obvious noise (archive / delete) without asking.
3. Queue replies / save-to-conduit / save-to-pile / skip for dispatch.
4. Dispatch each queued item:
   - **reply** → create Zoho Draft (source stays in inbox until sent)
   - **save-to-conduit** → resolve customer (Conduit search → Zoho CRM auto-import) → save phone_number/note → archive source
   - **save-to-pile** → create pile item with category/priority/client/project + popMail.do link → archive source
5. Dedupe pile by title (keep newest per title, drop the rest).

## Quick reference — operator's invariants

- **Inbox empty at end of day**: every message gets removed (archive/delete) or has a pile/Conduit artifact created first, then archive. **Never** propose `mark-read` as an action — it's been removed from the classifier.
- **Signature numbers are NOT customer phone numbers**: if the only numbers in an email are sender-signature lines (Office/Direct/Cell/Fax next to a name, or appearing after "Regards"/"Best"), do NOT propose save-to-conduit phone_number. Fall through to archive or save-to-pile. The classifier prompt encodes this rule; if it slips through, the operator deletes the bogus phone_number from Conduit.
- **Ewee-internal is NOT a Conduit customer**: never set `conduit_customer_hint` to "Ewee" / "EWEE Inc" / "Ewee NS" / "zEwee" / etc. Coworker @e-wee.com threads about internal coordination, financial reports, controller signatures → save-to-pile (if actionable) or archive (if FYI).
- **`Inbox Archive_Import` is OFF-LIMITS**: it's a 52k-message historical migration folder typed as `folderType=Inbox`. The script defaults to the top-level Inbox folder only (`inboxFolderIds = new Set([special.inbox])`); only pass `--all-inbox-folders` if explicitly requested.

## Setup (~3 min, do once per fresh Claude session)

```bash
# 1. SSH tunnel to pile prod Postgres (background; survives this session)
pkill -f "ssh.*54322:localhost:5432" 2>/dev/null; sleep 1
ssh -i ~/.ssh/id_ed25519 -fN -L 54322:localhost:5432 deploy@172.31.10.130 || \
  echo "alt: run as background via run_in_background: true"

# 2. Pull prod env file, rewrite DATABASE_URL host to the tunnel
ssh -i ~/.ssh/id_ed25519 deploy@172.31.10.130 'cat /opt/pile-data/.env' > /tmp/pile_prod_env
chmod 600 /tmp/pile_prod_env
sed -i -E 's#(DATABASE_URL=postgres(ql)?://[^@]+@)[^/]+(/.*)#\1127.0.0.1:54322\3#' /tmp/pile_prod_env

# 3. Mint a fresh Conduit JWT via the API container (expires ~13h after mint)
JWT=$(ssh -i ~/.ssh/id_ed25519 deploy@172.31.10.55 'docker exec conduit-api-1 python -c "
from app.database import SessionLocal
from app.models.entities import User
from app.security import create_user_access_token
db = SessionLocal()
u = db.query(User).filter(User.email==\"clayton.mannerow@e-wee.com\").first()
print(create_user_access_token(u.id, u.organization_id))
"')
```

Hosts (from `~/.ssh/config` aliases or [[ewee-smartpbx-droplet-roster]] memory):
- `deploy@172.31.10.130` = eweetools droplet (pile prod, Postgres at port 5432)
- `deploy@172.31.10.55` = conduit droplet (FastAPI at `conduitdocs.app/api`)
- Both reached via ZeroTier admin-overlay network.

## Running a batch

The pile repo at `/home/cmannerow/Nextcloud/Documents/programming/pile/server` contains `src/scripts/inbox_triage_oneoff.ts` with three relevant `--mode` values used here:

- `--mode=auto-noise --limit=N` — main batch runner. Walks N inbox messages, auto-executes archive/delete (no mark-read), queues the rest. Outputs JSON.
- `--mode=execute --message-id=ID --action=NAME [--reprocess]` — dispatch one item by id. Set `PROPOSAL_JSON=<full proposal>` to carry draft body / conduit payload / pile_item fields.
- `--mode=list --count-only` — quick inbox count.

The runner template **auto-detects the next batch number** by scanning `/tmp/batch*.json`, so you usually don't pass N:

```bash
JWT='...'   # from setup step 3
bash ~/.claude/skills/inbox-triage/runner.template.sh "$JWT"        # 500 msgs, next free N
bash ~/.claude/skills/inbox-triage/runner.template.sh "$JWT" 9      # force batch 9
bash ~/.claude/skills/inbox-triage/runner.template.sh "$JWT" 9 250  # batch 9, 250 msgs
```

Run via `run_in_background: true` since auto-noise on 500 messages plus dispatch takes ~30-40 min. The runner prints periodic markers (`=== BATCH N auto-noise ===`, `=== BATCH N queue dispatch ===`, `=== FINAL counts ===`) so a follow-up `tail` shows progress.

## After each batch — house-keeping pass

The dispatcher loop chains `save-to-pile` → source-archive automatically, but a few hygiene operations are worth running after each batch:

```bash
# Dedup pile by title (keep newest per title, drop the rest)
psql "$DATABASE_URL" -c "
WITH ranked AS (
  SELECT i.id, i.title,
         row_number() OVER (PARTITION BY i.title ORDER BY i.created_at DESC) AS rn,
         count(*) OVER (PARTITION BY i.title) AS dup
    FROM items i JOIN users u ON u.id=i.owner_user_id
   WHERE u.email='clayton.mannerow@e-wee.com' AND i.status='inbox'
), dupes AS (SELECT id FROM ranked WHERE dup > 1 AND rn > 1)
UPDATE items SET status='dropped' WHERE id IN (SELECT id FROM dupes) RETURNING 1;
" | wc -l
```

## Auditing the pile (drain side)

After several batches, pile fills up faster than it drains. The audit helper surfaces stuck/aging items so we can prioritize cleanup:

```bash
bash ~/.claude/skills/inbox-triage/audit-pile.sh
```

It reports: stuck p0 (> 24h old), aging p1 (> 5 days old), top clients with backlog (> 5 items), items missing source link, items missing category, duplicate titles, "review save candidate" stragglers, and concrete next-action recommendations.

Run it before/after batches; if pile is over ~1000, surface to the operator and pause new batches until they review.

## Quality / reporting after a batch

```bash
# What got done in the last N hours
psql "$DATABASE_URL" -c "
SELECT after->>'proposed_action' AS action, count(*)
FROM audit WHERE action='inbox_triage_decision' AND at > NOW() - interval '2 hours'
GROUP BY 1 ORDER BY 2 DESC;
"
# Email inbox count
cd /home/cmannerow/Nextcloud/Documents/programming/pile/server && \
  USER_EMAIL='clayton.mannerow@e-wee.com' pnpm exec tsx \
    src/scripts/inbox_triage_oneoff.ts --mode=list --count-only
# Pile inbox count
psql "$DATABASE_URL" -tAc "
SELECT count(*) FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='clayton.mannerow@e-wee.com' AND i.status='inbox';"
```

## Known failure modes + their fixes

| Failure | Why | Fix |
|---|---|---|
| `zoho iterInbox 401` mid-loop | Token expires > 1h | iterator already accepts a getter callback (commit `2770f1a`); make sure runner passes `refreshToken` not a static string |
| Conduit `/integrations/zoho/crm/search` returns 502 with `400 from /oauth/v2/token` | Conduit's CRM refresh-token state is broken | Open / link [smartpbx/conduit#609](https://github.com/smartpbx/conduit/issues/609). Until fixed, auto-import won't work; LLM proposals fall through to pile fallback |
| `getMessageDetail` 404 INVALID_METHOD | Bare `/messages/{id}` doesn't exist; needs `/details` + `/content` | Already fixed in `zoho_mail_actions.ts:getMessageDetail` |
| `moveMessage` 400 "Destination folderId is null" | Zoho's move endpoint is opaque; every destination-field variant fails | `archiveMessage` + `moveToTrash` collapse to DELETE-folder-scoped (= Trash); audit records operator intent so we can replay if a real move is figured out later |
| Phone-number 422 "notes Input should be a valid string" | LLM returns `notes: {text: "..."}` instead of string | `toStr()` coercion in the script handles this |
| Misattributed phone numbers (signature line attached to customer) | LLM picks up sig number, mislabels | Strengthened classifier prompt; if it still slips through, delete via Conduit API + audit |
| `whiptail` segfault on Vaultwarden update | No TTY over SSH | Use `pct enter 104` from proxmox for a real shell |

## Stop conditions / when to surface to operator

- Per-item Conduit save failures > 10 in one batch → likely a Conduit-side issue, surface before continuing
- LLM proposes save-to-conduit for "Ewee" / "EWEE Inc" repeatedly → prompt isn't being followed; check that local script has commit `5973748+` and `2770f1a+`
- Pile inbox grows past ~1000 → run enrichment + dedup; consider pause + manual review
- JWT expired → mint a new one (setup step 3)

## Files this skill assumes exist

- `~/.ssh/id_ed25519` — SSH key for eweetools + conduit droplets (ZT admin overlay)
- `~/.ssh/config` aliases `proxmox` (for the home Proxmox host) — not used by this skill directly but adjacent infra
- `/home/cmannerow/Nextcloud/Documents/programming/pile/server` — pile checkout (`main` branch with commits `2770f1a` and `308bc7f` at minimum)
- `/tmp/pile_prod_env` — written by setup step 2
- `runner.template.sh` (this folder)

## Memory references

- [[ewee-smartpbx-droplet-roster]] — public + ZT admin IPs for the 3 smartpbx droplets
- [[zerotier-setup-on-laptop]] — ZT networks this machine is joined to
