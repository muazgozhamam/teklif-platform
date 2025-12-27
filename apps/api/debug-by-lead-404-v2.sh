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
  -d '{"initialText":"debug by-lead 404 v2"}')"

echo "Lead body:"
echo "$LEAD_JSON"

LEAD_ID="$(node - <<'NODE'
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(0,"utf8"));
if(!j.id){ console.error("id yok:", j); process.exit(2); }
process.stdout.write(j.id);
NODE
<<<"$LEAD_JSON")"

echo
echo "==> LEAD_ID=$LEAD_ID"

echo
echo "==> 2) GET /deals/by-lead/:leadId (status + body)"
curl -i "$BASE/deals/by-lead/$LEAD_ID" || true

echo
echo "==> 3) Swagger json'da deals path araması"
curl -sS "$BASE/docs-json" | grep -Eo '"/deals[^"]*"' | head -n 50 || true

echo
echo "==> DONE"
