#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-consultant1@test.com}"
CONSULTANT_PASSWORD="${CONSULTANT_PASSWORD:-pass123}"

json_get() {
  local expr="$1"
  node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync(0,'utf8'));const v=(function(){try{return $expr}catch{return ''}})();process.stdout.write(v===undefined||v===null?'':String(v));"
}

must_login() {
  local email="$1"
  local password="$2"
  local j
  j="$(curl -fsS -X POST "$BASE_URL/auth/login" -H "Content-Type: application/json" -d "{\"email\":\"$email\",\"password\":\"$password\"}")"
  local t
  t="$(echo "$j" | json_get "j.access_token || j.accessToken || ''")"
  [ -n "$t" ] || { echo "HATA: login token yok ($email)"; echo "$j"; exit 1; }
  echo "$t"
}

contains_id() {
  local id="$1"
  node -e "const fs=require('fs');const raw=fs.readFileSync(0,'utf8');let j;try{j=JSON.parse(raw)}catch{process.stdout.write('false');process.exit(0)};const arr=Array.isArray(j)?j:(Array.isArray(j.items)?j.items:[]);process.stdout.write(arr.some(x=>x&&x.id==='${id}')?'true':'false');"
}

echo "==> BASE_URL=$BASE_URL"

echo "==> 0) Login(admin)"
ADMIN_TOKEN="$(must_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
ADMIN_AUTH="Authorization: Bearer $ADMIN_TOKEN"
echo "OK admin=$ADMIN_EMAIL"

echo "==> 1) Lead create"
LEAD_JSON="$(curl -fsS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{"initialText":"phase1 smoke broker approve to listing"}')"
LEAD_ID="$(echo "$LEAD_JSON" | json_get "j.id || ''")"
[ -n "$LEAD_ID" ] || { echo "HATA: LEAD_ID yok"; echo "$LEAD_JSON"; exit 2; }
echo "OK leadId=$LEAD_ID"

echo "==> 2) Broker approve (auto deal create)"
APPROVE_JSON="$(curl -fsS -X POST "$BASE_URL/broker/leads/$LEAD_ID/approve" -H "$ADMIN_AUTH" -H "Content-Type: application/json" -d '{}')"
DEAL_ID="$(echo "$APPROVE_JSON" | json_get "j.dealId || ''")"
CREATED_DEAL="$(echo "$APPROVE_JSON" | json_get "j.createdDeal || ''")"
[ -n "$DEAL_ID" ] || { echo "HATA: approve sonrası dealId yok"; echo "$APPROVE_JSON"; exit 3; }
echo "OK dealId=$DEAL_ID createdDeal=$CREATED_DEAL"

LEAD_STATUS="$(curl -fsS "$BASE_URL/leads/$LEAD_ID" | json_get "j.status || ''")"
[ "$LEAD_STATUS" = "APPROVED" ] || { echo "HATA: lead status APPROVED değil ($LEAD_STATUS)"; exit 3; }

echo "==> 3) Login(consultant)"
CONSULTANT_TOKEN="$(must_login "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD")"
CONSULTANT_AUTH="Authorization: Bearer $CONSULTANT_TOKEN"
echo "OK consultant=$CONSULTANT_EMAIL"

echo "==> 4) Pending inbox contains deal"
PENDING_JSON="$(curl -fsS -H "$CONSULTANT_AUTH" "$BASE_URL/deals/inbox/pending?take=50&skip=0")"
IN_PENDING="$(echo "$PENDING_JSON" | contains_id "$DEAL_ID")"
[ "$IN_PENDING" = "true" ] || { echo "HATA: deal pending listesinde yok"; exit 4; }

echo "==> 5) Consultant claim (assign-to-me)"
ASSIGN_JSON="$(curl -fsS -X POST "$BASE_URL/deals/$DEAL_ID/assign-to-me" -H "$CONSULTANT_AUTH" -H "Content-Type: application/json" -d '{}')"
ASSIGN_STATUS="$(echo "$ASSIGN_JSON" | json_get "j.status || ''")"
[ "$ASSIGN_STATUS" = "ASSIGNED" ] || { echo "HATA: assign sonrası status ASSIGNED değil"; echo "$ASSIGN_JSON"; exit 5; }

echo "==> 6) Mine inbox contains deal"
MINE_JSON="$(curl -fsS -H "$CONSULTANT_AUTH" "$BASE_URL/deals/inbox/mine?take=50&skip=0")"
IN_MINE="$(echo "$MINE_JSON" | contains_id "$DEAL_ID")"
[ "$IN_MINE" = "true" ] || { echo "HATA: deal mine listesinde yok"; exit 6; }

echo "==> 7) Listing upsert from deal"
UP1="$(curl -fsS -i -X POST "$BASE_URL/listings/deals/$DEAL_ID/listing" -H "$CONSULTANT_AUTH")"
UP1_CODE="$(echo "$UP1" | node -e "const fs=require('fs');const s=fs.readFileSync(0,'utf8');const m=s.match(/HTTP\\/[^\\s]+\\s+([0-9]{3})/g);const c=(m&&m.length)?(m[m.length-1].match(/([0-9]{3})/)||[])[1]:'';process.stdout.write(c);")"
UP1_BODY="$(echo "$UP1" | node -e "const fs=require('fs');const s=fs.readFileSync(0,'utf8');const i=s.lastIndexOf('\\r\\n\\r\\n');if(i>=0){process.stdout.write(s.slice(i+4));process.exit(0)}const j=s.lastIndexOf('\\n\\n');process.stdout.write(j>=0?s.slice(j+2):s);")"
LISTING_ID="$(echo "$UP1_BODY" | json_get "j.id || ''")"
[ -n "$LISTING_ID" ] || { echo "HATA: listing oluşturulamadı"; echo "$UP1_BODY"; exit 7; }
[ "$UP1_CODE" = "201" ] || [ "$UP1_CODE" = "200" ] || { echo "HATA: upsert code=$UP1_CODE"; exit 7; }
echo "OK listingId=$LISTING_ID code=$UP1_CODE"

echo "==> 8) Final doğrulama"
DEAL_FINAL="$(curl -fsS "$BASE_URL/deals/$DEAL_ID")"
DEAL_LISTING_ID="$(echo "$DEAL_FINAL" | json_get "j.listingId || ''")"
[ "$DEAL_LISTING_ID" = "$LISTING_ID" ] || { echo "HATA: deal.listingId eşleşmiyor"; exit 8; }

LISTING_FINAL="$(curl -fsS -H "$CONSULTANT_AUTH" "$BASE_URL/listings/$LISTING_ID")"
TITLE="$(echo "$LISTING_FINAL" | json_get "j.title || ''")"
[ -n "$TITLE" ] || { echo "HATA: listing title boş"; exit 8; }

echo
echo "✅ SMOKE OK (phase1 broker-approve-to-listing)"
echo "leadId=$LEAD_ID"
echo "dealId=$DEAL_ID"
echo "listingId=$LISTING_ID"
