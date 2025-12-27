#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

BASE_URL="${BASE_URL:-http://localhost:3001}"
LOG=".tmp/api-dev-3001.log"

sep(){ echo "------------------------------------------------------------"; }

echo "==> BASE_URL=$BASE_URL"
sep
echo "==> 0) Health"
curl -sS --max-time 5 "$BASE_URL/health" | jq -e . >/dev/null
echo "OK: health"

sep
echo "==> 1) Create lead"
LEAD_JSON="$(curl -sS --max-time 10 -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{"initialText":"debug post deal->listing"}')"
LEAD_ID="$(echo "$LEAD_JSON" | jq -r .id)"
test -n "$LEAD_ID" && test "$LEAD_ID" != "null"
echo "OK: LEAD_ID=$LEAD_ID"

sep
echo "==> 2) Get deal by lead"
DEAL_JSON="$(curl -sS --max-time 10 "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(echo "$DEAL_JSON" | jq -r .id)"
test -n "$DEAL_ID" && test "$DEAL_ID" != "null"
echo "OK: DEAL_ID=$DEAL_ID"

sep
echo "==> 3) Wizard minimal answers (city,district,type,rooms)"
# next-question loop (max 10)
for i in $(seq 1 10); do
  Q="$(curl -sS --max-time 10 -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  DONE="$(echo "$Q" | jq -r .done)"
  if [ "$DONE" = "true" ]; then
    echo "Wizard done."
    break
  fi

  KEY="$(echo "$Q" | jq -r '.key // .field // empty')"
  test -n "$KEY"

  case "$KEY" in
    city) ANSWER="Konya" ;;
    district) ANSWER="Meram" ;;
    type) ANSWER="satılık" ;;
    rooms) ANSWER="3+1" ;;
    *) ANSWER="test" ;;
  esac

  echo "Q$i: key=$KEY -> $ANSWER"
  curl -sS --max-time 10 -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$KEY\",\"answer\":\"$ANSWER\"}" >/dev/null
done

sep
echo "==> 4) DEBUG POST /listings/deals/:dealId/listing (timeout + http code)"
RESP_FILE=".tmp/post-listing-resp.json"
rm -f "$RESP_FILE"

HTTP_CODE="$(curl -sS --show-error --max-time 15 \
  -o "$RESP_FILE" -w "%{http_code}" \
  -X POST "$BASE_URL/listings/deals/$DEAL_ID/listing")" || true

echo "HTTP_CODE=$HTTP_CODE"
echo "--- BODY (first 200 lines) ---"
if [ -f "$RESP_FILE" ]; then
  sed -n '1,200p' "$RESP_FILE" || true
else
  echo "(no body file)"
fi

sep
echo "==> 5) Tail API log (last 120 lines)"
if [ -f "$LOG" ]; then
  tail -n 120 "$LOG" || true
else
  echo "(log not found: $LOG)"
fi

sep
echo "✅ ADIM 8 DONE (debug output above)"
