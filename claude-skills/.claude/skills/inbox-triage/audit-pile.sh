#!/usr/bin/env bash
# Audit Clayton's pile inbox for triage hygiene. Surfaces things that
# need attention so we don't just keep feeding pile without draining.
#
# Usage: bash audit-pile.sh
# Requires: /tmp/pile_prod_env loaded (DATABASE_URL pointing at the
# tunnel) — same setup as the runner.

set -uo pipefail
set -a; . /tmp/pile_prod_env; set +a

USER_EMAIL='clayton.mannerow@e-wee.com'

echo "=== TOTAL pile inbox ==="
psql "$DATABASE_URL" -tAc "
SELECT count(*) FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox';"

echo
echo "=== STUCK p0 items (urgent, > 24h old, no due date set, no progress) ==="
psql "$DATABASE_URL" -c "
SELECT to_char(i.created_at, 'MM-DD HH24:MI') AS created,
       substr(i.title, 1, 70) AS title,
       coalesce(i.client, '-') AS client
FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox' AND i.priority='p0'
  AND i.created_at < NOW() - interval '24 hours'
ORDER BY i.created_at ASC LIMIT 10;"

echo
echo "=== Aging p1 items (this-week priority, > 5 days old) ==="
psql "$DATABASE_URL" -c "
SELECT to_char(i.created_at, 'MM-DD') AS created,
       substr(i.title, 1, 60) AS title,
       coalesce(i.client, '-') AS client
FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox' AND i.priority='p1'
  AND i.created_at < NOW() - interval '5 days'
ORDER BY i.created_at ASC LIMIT 10;"

echo
echo "=== Top clients with backlog (> 5 items in inbox) ==="
psql "$DATABASE_URL" -c "
SELECT i.client, count(*) AS items, count(*) FILTER (WHERE i.priority IN ('p0','p1')) AS hot
FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox' AND i.client IS NOT NULL
GROUP BY i.client HAVING count(*) > 5
ORDER BY items DESC, hot DESC LIMIT 10;"

echo
echo "=== Items with no source link (broken link to email) ==="
psql "$DATABASE_URL" -tAc "
SELECT count(*) FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox'
  AND i.external_url IS NULL;"

echo
echo "=== Items with NO category (enrichment didn't catch them) ==="
psql "$DATABASE_URL" -tAc "
SELECT count(*) FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox'
  AND i.category IS NULL;"

echo
echo "=== Duplicate titles still in inbox ==="
psql "$DATABASE_URL" -c "
SELECT count(*) AS dup_n, substr(i.title, 1, 60) AS title
FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox'
GROUP BY i.title HAVING count(*) > 1
ORDER BY dup_n DESC LIMIT 10;"

echo
echo "=== 'review save candidate' stragglers (failed Conduit fallback) ==="
psql "$DATABASE_URL" -c "
SELECT to_char(i.created_at, 'MM-DD') AS created,
       substr(i.title, 33, 60) AS subject_excerpt
FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox'
  AND i.title LIKE 'Inbox triage: review save candidate%'
ORDER BY i.created_at DESC LIMIT 10;"

echo
echo "=== Recommended next actions ==="
DUPS=$(psql "$DATABASE_URL" -tAc "
WITH d AS (SELECT count(*) c, i.title FROM items i JOIN users u ON u.id=i.owner_user_id
           WHERE u.email='$USER_EMAIL' AND i.status='inbox'
           GROUP BY i.title HAVING count(*) > 1)
SELECT COALESCE(sum(c-1)::text, '0') FROM d;")
NO_CAT=$(psql "$DATABASE_URL" -tAc "
SELECT count(*) FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox' AND i.category IS NULL;")
NO_URL=$(psql "$DATABASE_URL" -tAc "
SELECT count(*) FROM items i JOIN users u ON u.id=i.owner_user_id
WHERE u.email='$USER_EMAIL' AND i.status='inbox' AND i.external_url IS NULL;")

[ "$DUPS" != "0" ] && echo "  - $DUPS duplicates → run runner's dedup query or rebuild pile dedup pass"
[ "$NO_CAT" != "0" ] && echo "  - $NO_CAT items missing category → run enrich_pile.ts"
[ "$NO_URL" != "0" ] && echo "  - $NO_URL items missing source link → run backfill SQL (see SKILL.md)"

echo "Done."
