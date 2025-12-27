#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> BASE_URL=$BASE_URL"
echo

echo "==> 1) Create lead"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "smoke lead wizard -> key/value -> ready -> match" }')"
echo "$LEAD_JSON"
LEAD_ID="$(node -e 'try{const j=JSON.parse(process.argv[1]); console.log(j.id||"")}catch{console.log("")}' "$LEAD_JSON")"
[ -n "$LEAD_ID" ] || { echo "HATA: lead id yok"; exit 1; }
echo "OK: LEAD_ID=$LEAD_ID"
echo

echo "==> 2) Get deal by lead"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
echo "$DEAL_JSON" | head -c 1200; echo
DEAL_ID="$(node -e 'try{const j=JSON.parse(process.argv[1]); console.log(j.id||"")}catch{console.log("")}' "$DEAL_JSON")"
[ -n "$DEAL_ID" ] || { echo "HATA: deal id yok"; exit 1; }
STATUS="$(node -e 'try{const j=JSON.parse(process.argv[1]); console.log(j.status||"")}catch{console.log("")}' "$DEAL_JSON")"
echo "OK: DEAL_ID=$DEAL_ID status=$STATUS"
echo

ANSWER_URL="$BASE_URL/leads/$LEAD_ID/answer"

deal_status() {
  curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" | node -e '
    let d=""; process.stdin.on("data",c=>d+=c);
    process.stdin.on("end",()=>{try{const j=JSON.parse(d); console.log(j.status||"")}catch{console.log("")}})
  '
}

try_payload () {
  local payload="$1"
  echo "---"
  echo "PUT $ANSWER_URL"
  echo "payload: $payload"
  curl -sS -i -X PUT "$ANSWER_URL" -H "Content-Type: application/json" -d "$payload" | sed -n '1,60p'
  echo
  echo "deal.status now => $(deal_status)"
  echo
}

echo "==> 3) Answer wizard with key/value guesses"

# En olası DTO: { key: string, value: any }
# (Bazı implementasyonlarda value yerine answer da olabilir; ama error "key" dediği için önce key/value deniyoruz.)

PAYLOADS=(
  '{"key":"city","value":"Konya"}'
  '{"key":"district","value":"Meram"}'
  '{"key":"type","value":"SATILIK"}'
  '{"key":"rooms","value":"2+1"}'

  # farklı isimlendirme ihtimalleri
  '{"key":"deal.city","value":"Konya"}'
  '{"key":"deal.district","value":"Meram"}'
  '{"key":"deal.type","value":"SATILIK"}'
  '{"key":"deal.rooms","value":"2+1"}'

  # value yerine answer kullanan DTO ihtimali
  '{"key":"city","answer":"Konya"}'
  '{"key":"district","answer":"Meram"}'
  '{"key":"type","answer":"SATILIK"}'
  '{"key":"rooms","answer":"2+1"}'

  # wizard bitiş flag'leri (bazı servisler son adımda DONE true bekler)
  '{"key":"done","value":true}'
  '{"key":"isDone","value":true}'
  '{"key":"completed","value":true}'
)

for p in "${PAYLOADS[@]}"; do
  try_payload "$p" || true
  STATUS="$(deal_status)"
  if [ "$STATUS" = "READY_FOR_MATCHING" ]; then
    echo "✅ Deal READY_FOR_MATCHING oldu."
    break
  fi
done

STATUS="$(deal_status)"
if [ "$STATUS" != "READY_FOR_MATCHING" ]; then
  echo "HATA: Deal status READY_FOR_MATCHING’e geçmedi."
  echo "Bu noktada Swagger requestBody şemasını görmek şart."
  echo "Çalıştır:"
  echo "  bash scripts/inspect-leads-answer-swagger.sh"
  exit 2
fi

echo
echo "==> 4) Match deal"
curl -sS -i -X POST "$BASE_URL/deals/$DEAL_ID/match" | sed -n '1,120p'
echo
echo "DONE."
