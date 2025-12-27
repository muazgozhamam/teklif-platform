#!/usr/bin/env bash
set -euo pipefail
BASE="http://localhost:3001"

echo "==> 0) Health"
curl -fsS "$BASE/health" >/dev/null
echo "   OK"

echo
echo "==> 1) Lead create"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"E2E advance test"}')"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id)' "$LEAD_JSON")"
echo "   LEAD_ID=$LEAD_ID"

echo
echo "==> 2) Deal by lead"
DEAL_JSON="$(curl -fsS "$BASE/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write((j.deal||j).id)' "$DEAL_JSON")"
echo "   DEAL_ID=$DEAL_ID"
echo "   Deal: $DEAL_JSON"

echo
echo "==> 3) Advance QUESTIONS_COMPLETED"
ADV_JSON="$(curl -fsS -X POST "$BASE/deals/$DEAL_ID/advance" -H "Content-Type: application/json" -d '{"event":"QUESTIONS_COMPLETED"}')"
echo "   Advance response: $ADV_JSON"

echo
echo "==> DONE"
