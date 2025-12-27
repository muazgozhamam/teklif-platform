#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
BASE_URL="http://localhost:3001"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' yok"; exit 1; }; }
need curl

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; fi

echo "==> 0) Health"
curl -sS "$BASE_URL/health" | (jq || cat)
echo

echo "==> 1) Lead oluştur"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "e2e wizard + guard test" }')"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$LEAD_JSON" | jq; else echo "$LEAD_JSON"; fi
LEAD_ID="$(echo "$LEAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
echo "LEAD_ID=$LEAD_ID"
echo

echo "==> 2) Wizard tamamla (Konya/Selçuklu/SATILIK/2+1)"
# q1
NQ="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
DEAL_ID="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin)['dealId'])")"
echo "DEAL_ID=$DEAL_ID"

curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" -H "Content-Type: application/json" -d '{ "answer": "Konya" }' >/dev/null
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" -H "Content-Type: application/json" -d '{ "answer": "Selçuklu" }' >/dev/null
curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" -H "Content-Type: application/json" -d '{ "answer": "SATILIK" }' >/dev/null
DONE_JSON="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" -H "Content-Type: application/json" -d '{ "answer": "2+1" }')"

if [[ "$HAS_JQ" -eq 1 ]]; then echo "$DONE_JSON" | jq; else echo "$DONE_JSON"; fi
echo

echo "==> 3) Deal çek ve status kontrol et"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$DEAL_JSON" | jq; else echo "$DEAL_JSON"; fi

STATUS="$(echo "$DEAL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status'))")"
echo "STATUS=$STATUS"
echo

echo "==> 4) Match guard testi"
echo "-- 4A) Status READY_FOR_MATCHING değilse match çağırıp reddediyor mu?"
# Burada iki senaryo var:
# - Eğer status zaten READY_FOR_MATCHING ise bu adımı skip ediyoruz.
# - Eğer değilse, match'in 4xx dönmesi beklenir.
if [[ "$STATUS" != "READY_FOR_MATCHING" ]]; then
  RES="$(curl -sS -i -X POST "$BASE_URL/deals/$DEAL_ID/match" || true)"
  echo "$RES" | sed -n '1,12p'
  echo
  echo "Beklenen: 4xx + 'not READY_FOR_MATCHING' benzeri mesaj."
else
  echo "SKIP: Status zaten READY_FOR_MATCHING."
fi
echo

echo "-- 4B) Status READY_FOR_MATCHING ise match çalışmalı"
if [[ "$STATUS" == "READY_FOR_MATCHING" ]]; then
  MATCH_JSON="$(curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/match")"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$MATCH_JSON" | jq; else echo "$MATCH_JSON"; fi
else
  echo "⚠️ Status READY_FOR_MATCHING değil. Wizard done=true olunca bu status'a set edilmiyorsa, bir sonraki patch: wizard tamamlanınca status'u READY_FOR_MATCHING'e çekmek."
fi

echo
echo "Özet:"
echo "- LEAD_ID=$LEAD_ID"
echo "- DEAL_ID=$DEAL_ID"
echo "- STATUS=$STATUS"
