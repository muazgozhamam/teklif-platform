#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing: $1"; exit 1; }; }
need curl
need node
command -v jq >/dev/null 2>&1 && HAS_JQ=1 || HAS_JQ=0

echo "==> 1) Lead oluştur"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" \
  -H "Content-Type: application/json" \
  -d '{ "initialText": "wizard test" }')"

if [[ "$HAS_JQ" -eq 1 ]]; then
  echo "$LEAD_JSON" | jq
else
  echo "$LEAD_JSON"
fi

LEAD_ID="$(node -p 'JSON.parse(process.argv[1]).id' "$LEAD_JSON")"
echo "LEAD_ID=$LEAD_ID"

echo
echo "==> 2) Next-question"
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question" | { [[ "$HAS_JQ" -eq 1 ]] && jq || cat; }

echo
echo "==> 3) Answer: Konya"
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
  -H "Content-Type: application/json" \
  -d '{ "answer": "Konya" }' | { [[ "$HAS_JQ" -eq 1 ]] && jq || cat; }

echo
echo "==> 4) Next-question (bir sonraki adım gelmeli)"
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question" | { [[ "$HAS_JQ" -eq 1 ]] && jq || cat; }

echo
echo "✅ Wizard test OK"
