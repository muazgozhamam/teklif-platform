#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"

echo "==> 0) Health"
curl -fsS "$BASE/health" >/dev/null
echo "   OK"

echo
echo "==> 1) Lead create (body only)"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" \
  -H "Content-Type: application/json" \
  -d '{"initialText":"debug by-lead 404 v3"}')"

echo "Lead body: $LEAD_JSON"

LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id||"")' "$LEAD_JSON")"
echo "==> LEAD_ID=$LEAD_ID"

if [ -z "$LEAD_ID" ]; then
  echo "HATA: LEAD_ID boş. Lead response içinde id yok."
  exit 1
fi

echo
echo "==> 2) GET /deals/by-lead/:leadId (status + body)"
curl -i "$BASE/deals/by-lead/$LEAD_ID" || true

echo
echo "==> DONE"
