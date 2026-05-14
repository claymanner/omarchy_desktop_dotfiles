#!/usr/bin/env bash
# Canonical batch runner for the inbox-triage skill.
#
# Usage:
#   bash runner.template.sh <CONDUIT_JWT> [BATCH_NUM] [LIMIT]
#
# Defaults: BATCH_NUM=N (override), LIMIT=500.
#
# What it does:
#   1. Auto-noise sweep of LIMIT messages.
#   2. Dispatcher loop: drafts replies, saves to Conduit (with CRM auto-import
#      fallback), creates pile items, archives sources.
#   3. Pile dedup (drop duplicates by title).
#   4. Final inbox + pile counts.
#
# Side effects: every action writes an `audit` row in pile with
# operator_decision='auto' for noise, 'y' for queued dispositions.

set -uo pipefail

JWT="${1:?usage: runner.template.sh <CONDUIT_JWT> [N] [LIMIT]}"
# Auto-detect the next batch number: scan /tmp/batch*.json (the per-batch
# output artifact written by the auto-noise pass) and pick max+1.
# Override with arg 2; falls back to 1 when no prior batch exists.
LATEST=$(ls /tmp/batch*.json 2>/dev/null | grep -oE 'batch[0-9]+' | grep -oE '[0-9]+' | sort -n | tail -1)
N="${2:-$((${LATEST:-0}+1))}"
LIMIT="${3:-500}"
echo "(running as batch ${N}; latest prior batch: ${LATEST:-none})"

cd /home/cmannerow/Nextcloud/Documents/programming/pile/server

set -a; . /tmp/pile_prod_env; set +a
export CONDUIT_JWT="$JWT" USER_EMAIL='clayton.mannerow@e-wee.com'

# Per-batch artifact paths.
BATCH_JSON="/tmp/batch${N}.json"
QUEUE_JSONL="/tmp/b${N}_queue.jsonl"
DISP_LOG="/tmp/b${N}_disposition.log"

dispatch_queue() {
  local file="$1" log="$2"
  while IFS= read -r line <&3; do
    mid=$(echo "$line" | jq -r '.message_id')
    action=$(echo "$line" | jq -r '.proposal.action')
    pjson=$(echo "$line" | jq -c '.proposal')
    subj=$(echo "$line" | jq -r '.subject // ""')

    if [ "$action" = "reply" ] || [ "$action" = "save-to-pile" ]; then
      PROPOSAL_JSON="$pjson" pnpm exec tsx src/scripts/inbox_triage_oneoff.ts \
        --mode=execute --message-id="$mid" --action="$action" </dev/null >> "$log" 2>&1
    elif [ "$action" = "save-to-conduit" ]; then
      # The script's resolveCustomer does Conduit search → Zoho CRM
      # auto-import → null. We only fall back to a pile placeholder
      # when both paths miss.
      PROPOSAL_JSON="$pjson" pnpm exec tsx src/scripts/inbox_triage_oneoff.ts \
        --mode=execute --message-id="$mid" --action=save-to-conduit </dev/null \
        > /tmp/_tmp_exec.json 2>&1
      cat /tmp/_tmp_exec.json >> "$log"
      if grep -q '"executed": false' /tmp/_tmp_exec.json; then
        body=$(echo "$line" | jq -r '
          "Source: " + .from + "\nSubject: " + .subject +
          "\nLLM rationale: " + (.proposal.rationale // "") +
          "\nExtracted payload: " + (.proposal.conduit_payload | tostring)')
        fp=$(jq -n --arg t "Inbox triage: review save candidate — $subj" --arg b "$body" \
              '{action:"save-to-pile",
                rationale:"Conduit save failed; saved as pile item.",
                pile_item:{title:$t, body:$b}}')
        PROPOSAL_JSON="$fp" pnpm exec tsx src/scripts/inbox_triage_oneoff.ts \
          --mode=execute --message-id="$mid" --action=save-to-pile --reprocess </dev/null \
          >> "$log" 2>&1
      fi
    fi
  done 3< "$file"
}

echo "=== BATCH ${N} auto-noise (limit=${LIMIT}) ==="
pnpm exec tsx src/scripts/inbox_triage_oneoff.ts --mode=auto-noise --limit="${LIMIT}" \
  > "$BATCH_JSON" 2>&1 || echo "batch${N} exit=$?"
jq '{scanned, executed_count, queued_count, skipped_count, failed_count}' "$BATCH_JSON" || true

echo "=== BATCH ${N} queue dispatch ==="
jq -c '.queued[]' "$BATCH_JSON" > "$QUEUE_JSONL"
: > "$DISP_LOG"
dispatch_queue "$QUEUE_JSONL" "$DISP_LOG"

echo "exec-success=$(grep -c '"executed": true' "$DISP_LOG")"
echo "already-decided=$(grep -c 'already decided' "$DISP_LOG")"

echo "=== Pile dedup pass ==="
psql "$DATABASE_URL" -tAc "
WITH ranked AS (
  SELECT i.id, i.title,
         row_number() OVER (PARTITION BY i.title ORDER BY i.created_at DESC) AS rn,
         count(*) OVER (PARTITION BY i.title) AS dup
    FROM items i JOIN users u ON u.id=i.owner_user_id
   WHERE u.email='clayton.mannerow@e-wee.com'
     AND i.created_at > NOW() - interval '24 hours'
     AND i.status='inbox'
), dupes AS (SELECT id FROM ranked WHERE dup > 1 AND rn > 1)
UPDATE items SET status='dropped' WHERE id IN (SELECT id FROM dupes) RETURNING 1;
" | wc -l

echo "=== FINAL counts ==="
pnpm exec tsx src/scripts/inbox_triage_oneoff.ts --mode=list --count-only 2>&1 | tail -5
echo "pile inbox now:"
psql "$DATABASE_URL" -tAc "
SELECT count(*) FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='clayton.mannerow@e-wee.com' AND i.status='inbox';"

echo "=== DONE ==="
