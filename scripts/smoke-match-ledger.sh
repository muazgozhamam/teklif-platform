#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> BASE_URL=$BASE_URL"

echo "==> 1) Create lead"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "smoke lead for match" }')"
echo "$LEAD_JSON"
LEAD_ID="$(node -e 'const s=process.argv[1]; try{const j=JSON.parse(s); console.log(j.id||"");}catch{console.log("")}' "$LEAD_JSON")"
[ -n "$LEAD_ID" ] || { echo "HATA: lead id parse edilemedi"; exit 1; }
echo "OK: LEAD_ID=$LEAD_ID"
echo

echo "==> 2) Get deal by lead"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
echo "$DEAL_JSON"
DEAL_ID="$(node -e 'const s=process.argv[1]; try{const j=JSON.parse(s); console.log(j.id||"");}catch{console.log("")}' "$DEAL_JSON")"
[ -n "$DEAL_ID" ] || { echo "HATA: deal id parse edilemedi"; exit 1; }
echo "OK: DEAL_ID=$DEAL_ID"
echo

echo "==> 3) Match deal"
curl -sS -i -X POST "$BASE_URL/deals/$DEAL_ID/match" | sed -n '1,120p'
echo

echo "==> 4) Ledger (if endpoint exists)"
# Varsayılan: broker ledger endpoint’i var mı diye kontrol
HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/broker/deals/$DEAL_ID/ledger" || true)"
echo "Ledger endpoint status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
  curl -sS "$BASE_URL/broker/deals/$DEAL_ID/ledger" | head -c 2000
  echo
else
  echo "Not: /broker/deals/:id/ledger 200 değil. Bu normal olabilir; route farklı olabilir."
fi

echo
echo "DONE."
