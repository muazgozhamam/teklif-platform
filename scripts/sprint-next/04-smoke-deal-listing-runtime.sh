#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

BASE_URL="${BASE_URL:-http://localhost:3001}"
MAX_STEPS="${MAX_STEPS:-10}"

sep(){ echo "------------------------------------------------------------"; }

echo "==> BASE_URL=$BASE_URL"
sep
echo "==> 0) Health"
curl -sS "$BASE_URL/health" | jq -e . >/dev/null
echo "OK: health"

sep
echo "==> 1) Create lead"
LEAD_JSON="$(curl -sS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{"initialText":"smoke deal->listing runtime"}')"
LEAD_ID="$(echo "$LEAD_JSON" | jq -r .id)"
test -n "$LEAD_ID" && test "$LEAD_ID" != "null"
echo "OK: LEAD_ID=$LEAD_ID"

sep
echo "==> 2) Get deal by lead"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(echo "$DEAL_JSON" | jq -r .id)"
test -n "$DEAL_ID" && test "$DEAL_ID" != "null"
echo "OK: DEAL_ID=$DEAL_ID"

sep
echo "==> 3) Wizard answer loop (max $MAX_STEPS)"
for i in $(seq 1 "$MAX_STEPS"); do
  Q="$(curl -sS --max-time 10 -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  DONE="$(echo "$Q" | jq -r .done)"
  if [ "$DONE" = "true" ]; then
    echo "Wizard done."

sep
echo "==> 3.5) POST /deals/:dealId/match (assign consultant)"
MATCH_URL="$BASE_URL/deals/$DEAL_ID/match"
echo "MATCH URL=$MATCH_URL"
MATCH_RESP_FILE=".tmp/smoke-step35-match.json"
MATCH_CODE="$(curl -sS --show-error --max-time 15 -o "$MATCH_RESP_FILE" -w "%{http_code}" -X POST "$MATCH_URL")" || true
echo "HTTP_CODE=$MATCH_CODE"
echo "--- BODY (first 120 lines) ---"
sed -n '1,120p' "$MATCH_RESP_FILE" 2>/dev/null || true
if [ "$MATCH_CODE" != "200" ] && [ "$MATCH_CODE" != "201" ]; then
  echo "ERR: Match failed (expected 200/201)"
  exit 1
fi
echo "OK: match"
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
    -d "{\"key\":\"$KEY\",\"answer\":\"$ANSWER\"}" | jq -e . >/dev/null
done

sep
echo "==> 4) POST /listings/deals/:dealId/listing (create/upsert)"
RESP_FILE=".tmp/smoke-step4-post-listing.json"
rm -f "$RESP_FILE"

URL="$BASE_URL/listings/deals/$DEAL_ID/listing"
echo "POST URL=$URL"

HTTP_CODE="$(curl -sS --show-error --max-time 15 -o "$RESP_FILE" -w "%{http_code}" -X POST "$URL")" || true
echo "HTTP_CODE=$HTTP_CODE"
echo "--- BODY (first 200 lines) ---"
if [ -f "$RESP_FILE" ]; then
  sed -n '1,200p' "$RESP_FILE" || true
else
  echo "(no body file)"
fi

# 200/201 bekliyoruz
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
  echo "ERR: Step 4 failed (expected 200/201)"
  exit 1
fi

LISTING_JSON="$(cat "$RESP_FILE")"
LISTING_ID="$(echo "$LISTING_JSON" | jq -r .id)"
test -n "$LISTING_ID" && test "$LISTING_ID" != "null"
echo "OK: LISTING_ID=$LISTING_ID"

sep
echo "==> 5) GET /listings/deals/:dealId/listing"
LISTING2="$(curl -sS --max-time 15 "$BASE_URL/listings/deals/$DEAL_ID/listing")"
LISTING2_ID="$(echo "$LISTING2" | jq -r .id)"
test "$LISTING2_ID" = "$LISTING_ID"
echo "OK: GET listing.id matches"

sep
echo "==> 6) Verify deal.listingId == listing.id"
DEAL2="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID")"
DEAL_LID="$(echo "$DEAL2" | jq -r '.listingId // empty')"
test -n "$DEAL_LID"
test "$DEAL_LID" = "$LISTING_ID"
echo "OK: deal.listingId=$DEAL_LID"

sep
echo "✅ PASS: runtime deal->listing"
