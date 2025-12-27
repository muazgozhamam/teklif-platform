#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> ROOT=$ROOT"
echo "==> BASE_URL=$BASE_URL"
echo

echo "==> 1) Health"
curl -sS -i "$BASE_URL/health" | sed -n '1,12p'
echo

echo "==> 2) Swagger"
curl -sS -i "$BASE_URL/docs" | sed -n '1,12p'
echo

echo "==> 3) Leads create (basic)"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "smoke lead" }')"
echo "$LEAD_JSON"
LEAD_ID="$(node -e 'const s=process.argv[1]; try{const j=JSON.parse(s); console.log(j.id||"");}catch{console.log("")}' "$LEAD_JSON")"

if [ -z "$LEAD_ID" ]; then
  echo "HATA: lead id parse edilemedi. Response yukarıda."
  exit 1
fi

echo "OK: LEAD_ID=$LEAD_ID"
echo

echo "==> 4) Deal by lead"
curl -sS -i "$BASE_URL/deals/by-lead/$LEAD_ID" | sed -n '1,60p'
echo
echo "DONE."
