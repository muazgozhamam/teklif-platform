#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> BASE_URL=$BASE_URL"

LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{"initialText":"smoke wizard -> match"}')"
echo "$LEAD_JSON"
LEAD_ID="$(echo "$LEAD_JSON" | node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(j.id||"");')"
[ -n "$LEAD_ID" ] || { echo "HATA: LEAD_ID yok"; exit 1; }
echo "OK: LEAD_ID=$LEAD_ID"

DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(echo "$DEAL_JSON" | node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(j.id||"");')"
[ -n "$DEAL_ID" ] || { echo "HATA: DEAL_ID yok"; echo "$DEAL_JSON"; exit 1; }
echo "OK: DEAL_ID=$DEAL_ID"

deal_status() {
  curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" | node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(j.status||"");'
}

answer_for_field() {
  case "$1" in
    city) echo "Konya" ;;
    district) echo "Meram" ;;
    type) echo "SATILIK" ;;
    rooms) echo "2+1" ;;
    *) echo "" ;;
  esac
}

echo
echo "==> Wizard Q/A"
for i in 1 2 3 4 5 6 7 8 9 10; do
  Q="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  echo "Q$i: $Q"

  FIELD="$(echo "$Q" | node -e 'const fs=require("fs"); const j=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(j.field||"");')"

  if [ -z "$FIELD" ]; then
    echo "Not: field gelmedi (muhtemelen wizard done)."
    break
  fi

  A="$(answer_for_field "$FIELD")"
  if [ -z "$A" ]; then
    echo "HATA: field=$FIELD için cevap yok"
    exit 2
  fi

  echo "-> answering: $FIELD = $A"
  curl -sS -i -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
    -H "Content-Type: application/json" \
    -d "{\"answer\":\"$A\"}" | sed -n '1,25p'
  echo "deal.status => $(deal_status)"
done

STATUS="$(deal_status)"
echo
echo "FINAL deal.status => $STATUS"

if [ "$STATUS" != "READY_FOR_MATCHING" ]; then
  echo "HATA: READY_FOR_MATCHING olmadı."
  echo "Bu durumda leads.service.ts içindeki wizardAnswer sonunda deal.status update yoktur."
  exit 3
fi

echo
echo "==> Match deal"
curl -sS -i -X POST "$BASE_URL/deals/$DEAL_ID/match" | sed -n '1,120p'
echo
echo "DONE."
