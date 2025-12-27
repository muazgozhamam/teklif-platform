#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://localhost:3001"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' yok"; exit 1; }; }
need curl

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; fi

echo "==> 0) Health"
curl -sS "$BASE_URL/health" | (jq || cat)
echo

echo "==> 1) Lead oluştur"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{ "initialText": "e2e-wizard-loop-status" }')"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$LEAD_JSON" | jq; else echo "$LEAD_JSON"; fi
LEAD_ID="$(echo "$LEAD_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
echo "LEAD_ID=$LEAD_ID"
echo

# Basit cevap haritası
answer_for_field() {
  case "$1" in
    city) echo "Konya" ;;
    district) echo "Selçuklu" ;;
    type) echo "SATILIK" ;;
    rooms) echo "2+1" ;;
    *) echo "TEST" ;;
  esac
}

echo "==> 2) Wizard döngüsü: next-question -> answer (done olana kadar)"
DEAL_ID=""
for i in {1..10}; do
  NQ="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$NQ" | jq; else echo "$NQ"; fi

  DONE="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin).get('done', False))")"
  if [[ "$DONE" == "True" || "$DONE" == "true" ]]; then
    DEAL_ID="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin)['dealId'])")"
    echo "✅ Wizard done=true (next-question aşamasında). DEAL_ID=$DEAL_ID"
    break
  fi

  DEAL_ID="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin)['dealId'])")"
  FIELD="$(echo "$NQ" | python3 -c "import sys,json; print(json.load(sys.stdin)['field'])")"
  ANS="$(answer_for_field "$FIELD")"

  echo "-> answer field=$FIELD = '$ANS'"
  RES="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" -H "Content-Type: application/json" -d "{ \"answer\": \"$ANS\" }")"
  if [[ "$HAS_JQ" -eq 1 ]]; then echo "$RES" | jq; else echo "$RES"; fi

  # Eğer answer response done:true döndüyse burada da çık
  ADONE="$(echo "$RES" | python3 -c "import sys,json; print(json.load(sys.stdin).get('done', False))")"
  if [[ "$ADONE" == "True" || "$ADONE" == "true" ]]; then
    echo "✅ Wizard done=true (answer response). DEAL_ID=$DEAL_ID"
    break
  fi

  echo
done

[[ -n "$DEAL_ID" ]] || { echo "❌ DEAL_ID yok. Wizard akışı beklenmedik."; exit 1; }
echo

echo "==> 3) Deal çek ve status kontrol"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/$DEAL_ID")"
if [[ "$HAS_JQ" -eq 1 ]]; then echo "$DEAL_JSON" | jq; else echo "$DEAL_JSON"; fi
STATUS="$(echo "$DEAL_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status'))")"
echo "STATUS=$STATUS"
echo

echo "Özet:"
echo "- LEAD_ID=$LEAD_ID"
echo "- DEAL_ID=$DEAL_ID"
echo "- STATUS=$STATUS"
