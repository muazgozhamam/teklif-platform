#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE_URL:-http://localhost:3001}"
CURL="curl -sS --connect-timeout 2 --max-time 8"

echo "==> create lead"
LEAD="$($CURL -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"doctor wizard advance"}')"
LEAD_ID="$(echo "$LEAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
echo "leadId=$LEAD_ID"
echo

echo "==> next (before)"
$CURL "$BASE/leads/$LEAD_ID/next" | python3 -m json.tool
echo

echo "==> answer via /leads/:id/answer  (POST {field,value})"
RESP="$($CURL -X POST "$BASE/leads/$LEAD_ID/answer" -H "Content-Type: application/json" -d '{"field":"city","value":"Konya"}')"
echo "$RESP" | python3 -m json.tool || echo "$RESP"
echo

echo "==> next (after)"
$CURL "$BASE/leads/$LEAD_ID/next" | python3 -m json.tool
echo
echo "✅ Eğer 'district' görüyorsan wizard ilerliyor demektir."
