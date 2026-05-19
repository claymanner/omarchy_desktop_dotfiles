/**
 * Retry pile items that the bulk-sweep flagged as p3 because Conduit's
 * Zoho CRM integration was 502'ing (issue smartpbx/conduit#609). Once
 * that's fixed, this re-attempts: resolveCustomer (Conduit search →
 * CRM auto-import) → save extracted data → drop the pile item.
 *
 * Uses the cached LLM scan stored in the original bulk-sweep audit row
 * so we DON'T re-pay for the LLM call.
 *
 * Usage:
 *   --apply        (default dry-run; apply to actually save+drop)
 *   --limit=N      (default 50 — pass higher for full retry)
 *
 * Required env: CONDUIT_JWT, DATABASE_URL, USER_EMAIL (defaults to
 * Clayton's).
 */

import { query } from '/home/cmannerow/Nextcloud/Documents/programming/pile/server/src/db/index.js';
import { ConduitClient } from '/home/cmannerow/Nextcloud/Documents/programming/pile/server/src/scripts/conduit_client.js';

const APPLY = process.argv.includes('--apply');
const LIMIT = (() => {
  const f = process.argv.find(a => a.startsWith('--limit='));
  return f ? Number(f.split('=')[1]) : 50;
})();
const USER_EMAIL = process.env.USER_EMAIL ?? 'clayton.mannerow@e-wee.com';

interface Scan {
  has_value?: boolean;
  customer?: string | null;
  attribution_confidence?: string;
  data_type?: string;
  extracted?: string[];
  payload?: Record<string, string | null | undefined>;
}

function normalizeDigits(s: string | null | undefined): string {
  return String(s ?? '').replace(/\D+/g, '');
}
const EWEE_SIG = new Set([
  '8333933067','6478009797','6478121337','6474775001','6479568239','4375619599'
]);

(async () => {
  const jwt = process.env.CONDUIT_JWT;
  if (!jwt) throw new Error('CONDUIT_JWT required');
  const conduit = new ConduitClient();
  conduit.setToken(jwt);

  const userRow = await query<{ id: string; org_id: string }>(
    `SELECT id, org_id FROM users WHERE email=$1`, [USER_EMAIL]
  );
  const user = userRow.rows[0]!;

  // Pull p3 items that have the CRM-502 marker in their body plus the
  // last audit row's stored `scan`. We use the most-recent matching
  // audit per item (in case the same item got flagged twice).
  const rows = await query<{ item_id: string; title: string; scan: Scan }>(
    `WITH latest AS (
       SELECT DISTINCT ON (a.after->>'pile_item_id')
              (a.after->>'pile_item_id')::uuid AS item_id,
              (a.after->'scan')                AS scan,
              a.at
         FROM audit a
        WHERE a.action='inbox_triage_decision'
          AND a.after->>'operator_decision'='bulk-sweep'
          AND a.after->'scan' IS NOT NULL
        ORDER BY a.after->>'pile_item_id', a.at DESC
     )
     SELECT i.id AS item_id, i.title, l.scan
       FROM items i
       JOIN users u ON u.id = i.owner_user_id
       JOIN latest l ON l.item_id = i.id
      WHERE u.email = $1
        AND i.status = 'inbox'
        AND i.priority = 'p3'
        AND i.body LIKE '%conduit %502%/zoho/crm/search%'
      ORDER BY i.created_at
      LIMIT $2`,
    [USER_EMAIL, LIMIT]
  );

  console.log(`Candidates: ${rows.rows.length} (limit=${LIMIT}, apply=${APPLY})\n`);

  const stats = { saved: 0, still_blocked: 0, no_match: 0, dropped: 0, error: 0 };

  for (const r of rows.rows) {
    const scan = r.scan ?? {};
    const customer = scan.customer ?? '';
    if (!customer || !scan.data_type || scan.data_type === 'none') {
      stats.no_match++;
      continue;
    }

    // Re-apply guardrails the original sweep used.
    if (scan.data_type === 'phone_number') {
      const digits = normalizeDigits(scan.payload?.number);
      if (EWEE_SIG.has(digits) || !(digits.length === 10 || (digits.length === 11 && digits.startsWith('1')))) {
        stats.no_match++;
        continue;
      }
    }

    try {
      const resolved = await conduit.resolveCustomer(customer);
      if (!resolved) {
        stats.still_blocked++;
        continue;
      }
      // Save
      if (scan.data_type === 'phone_number' && scan.payload?.number) {
        const systems = await conduit.listPhoneSystemsForCustomer(resolved.customer.id);
        if (systems.length === 0) { stats.no_match++; continue; }
        const p = scan.payload;
        await conduit.upsertPhoneNumber(systems[0]!.id, {
          number: String(p.number),
          label: p.label ?? null,
          line_kind: p.line_kind ?? null,
          system_port_label: p.system_port_label ?? null,
          bix_name: p.bix_name ?? null,
          bix_port: p.bix_port ?? null
        });
      } else if (scan.data_type === 'customer_note') {
        const text = (scan.payload?.text ?? (scan.extracted ?? []).join('; '));
        await conduit.appendCustomerNote(resolved.customer.id, text, new Date().toISOString().slice(0, 10));
      } else if (scan.data_type === 'phone_system_note') {
        const systems = await conduit.listPhoneSystemsForCustomer(resolved.customer.id);
        if (systems.length === 0) { stats.no_match++; continue; }
        const text = (scan.payload?.text ?? (scan.extracted ?? []).join('; '));
        await conduit.appendPhoneSystemNote(systems[0]!.id, text, new Date().toISOString().slice(0, 10));
      } else {
        stats.no_match++;
        continue;
      }
      stats.saved++;

      if (APPLY) {
        await query(`UPDATE items SET status='dropped' WHERE id=$1::uuid`, [r.item_id]);
        await query(
          `INSERT INTO audit (org_id, item_id, actor_user_id, action, after, actor_kind)
           VALUES ($1::uuid, $2::uuid, $3::uuid, 'inbox_triage_decision',
                   jsonb_build_object('pile_item_id', $4::text,
                                      'operator_decision','bulk-sweep-rerun',
                                      'result', $5::text, 'dry_run', false),
                   'user')`,
          [user.org_id, r.item_id, user.id, r.item_id,
           `rerun-blocked saved to Conduit (${customer}, ${scan.data_type})`]
        );
        stats.dropped++;
      }
    } catch (e) {
      const msg = (e as Error).message;
      if (msg.includes('502') || msg.includes('500')) stats.still_blocked++;
      else stats.error++;
    }
  }

  console.log(JSON.stringify(stats, null, 2));
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
