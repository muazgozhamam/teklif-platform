#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> ROOT=$ROOT"
echo "==> BASE_URL=$BASE_URL"
echo

# small helper: parse json with node
json_get() {
  node -e 'const j=JSON.parse(process.argv[1]||"{}"); const k=process.argv[2]; console.log((j&&j[k])||"");' "$1" "$2" 2>/dev/null || true
}

echo "==> 1) Create lead"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "smoke lead wizard -> ready -> match" }')"
echo "$LEAD_JSON"
LEAD_ID="$(node -e 'try{const j=JSON.parse(process.argv[1]); console.log(j.id||"")}catch{console.log("")}' "$LEAD_JSON")"
if [ -z "$LEAD_ID" ]; then
  echo "HATA: Lead id parse edilemedi."
  exit 1
fi
echo "OK: LEAD_ID=$LEAD_ID"
echo

echo "==> 2) Get deal by lead"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
echo "$DEAL_JSON" | head -c 1200; echo
DEAL_ID="$(node -e 'try{const j=JSON.parse(process.argv[1]); console.log(j.id||"")}catch{console.log("")}' "$DEAL_JSON")"
STATUS="$(node -e 'try{const j=JSON.parse(process.argv[1]); console.log(j.status||"")}catch{console.log("")}' "$DEAL_JSON")"
echo "OK: DEAL_ID=$DEAL_ID status=$STATUS"
echo

if [ -z "$DEAL_ID" ]; then
  echo "HATA: Deal id alınamadı."
  exit 1
fi

echo "==> 3) Try to advance wizard via PUT /leads/:id/answer"
ANSWER_URL="$BASE_URL/leads/$LEAD_ID/answer"

try_payload () {
  local payload="$1"
  echo "---"
  echo "PUT $ANSWER_URL"
  echo "payload: $payload"
  # show status line + first part of response
  curl -sS -i -X PUT "$ANSWER_URL" -H "Content-Type: application/json" -d "$payload" | sed -n '1,40p'
  echo
  # re-fetch deal status
  local dj
  dj="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
  local st
  st="$(node -e 'try{const j=JSON.parse(process.argv[1]); console.log(j.status||"")}catch{console.log("")}' "$dj")"
  echo "deal.status now => $st"
  echo
}

# A few common DTO shapes (we don't know exact one yet)
PAYLOADS=(
  '{"answer":"Konya"}'
  '{"text":"Konya"}'
  '{"value":"Konya"}'
  '{"answer":"Meram","done":false}'
  '{"answer":"Meram","isDone":false}'
  '{"answer":"Meram","step":"city"}'
  '{"answer":"Meram","field":"city"}'
  '{"done":true}'
  '{"isDone":true}'
  '{"completed":true}'
)

for p in "${PAYLOADS[@]}"; do
  try_payload "$p" || true
  STATUS="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const j=JSON.parse(d);console.log(j.status||"")}catch{console.log("")}})')"
  if [ "$STATUS" = "READY_FOR_MATCHING" ]; then
    echo "✅ Deal READY_FOR_MATCHING oldu."
    break
  fi
done

if [ "${STATUS:-}" != "READY_FOR_MATCHING" ]; then
  echo "HATA: Deal status READY_FOR_MATCHING'e ilerlemedi."
  echo "Bu durumda /leads/:id/answer request body DTO'su farklı."
  echo "Aşağıdaki script ile Swagger'dan endpoint body şemasını çıkaralım:"
  echo "  bash scripts/inspect-leads-answer-swagger.sh"
  exit 2
fi

echo
echo "==> 4) Match deal"
curl -sS -i -X POST "$BASE_URL/deals/$DEAL_ID/match" | sed -n '1,120p'
echo
echo "DONE."
