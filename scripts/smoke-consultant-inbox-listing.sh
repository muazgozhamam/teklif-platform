#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
LOGIN_EMAIL="${LOGIN_EMAIL:-consultant1@test.com}"
LOGIN_PASSWORD="${LOGIN_PASSWORD:-pass123}"

json_get() {
  local expr="$1"
  node -e "const fs=require('fs');const j=JSON.parse(fs.readFileSync(0,'utf8'));const v=(function(){try{return $expr}catch{return ''}})();process.stdout.write(v===undefined||v===null?'':String(v));"
}

http_status() {
  node -e "const fs=require('fs');const s=fs.readFileSync(0,'utf8');const m=s.match(/HTTP\/[0-9.]+\s+([0-9]{3})/g);if(!m||!m.length){process.stdout.write('');process.exit(0)}const last=m[m.length-1];const code=(last.match(/([0-9]{3})/)||[])[1]||'';process.stdout.write(code);"
}

body_only() {
  node -e "const fs=require('fs');const s=fs.readFileSync(0,'utf8');const idx=s.lastIndexOf('\r\n\r\n');if(idx>=0){process.stdout.write(s.slice(idx+4));process.exit(0)}const idx2=s.lastIndexOf('\n\n');process.stdout.write(idx2>=0?s.slice(idx2+2):s);"
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

echo "==> BASE_URL=$BASE_URL"
echo "==> 0) Login"
LOGIN_JSON="$(curl -fsS -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$LOGIN_EMAIL\",\"password\":\"$LOGIN_PASSWORD\"}")"
TOKEN="$(echo "$LOGIN_JSON" | json_get "j.access_token || j.accessToken || ''")"
[ -n "$TOKEN" ] || { echo "HATA: login token alınamadı"; echo "$LOGIN_JSON"; exit 1; }
AUTH_HEADER="Authorization: Bearer $TOKEN"
echo "OK loginEmail=$LOGIN_EMAIL"

echo "==> 1) Lead create"
LEAD_JSON="$(curl -fsS -X POST "$BASE_URL/leads" -H "Content-Type: application/json" -d '{"initialText":"smoke consultant inbox listing"}')"
LEAD_ID="$(echo "$LEAD_JSON" | json_get "j.id")"
[ -n "$LEAD_ID" ] || { echo "HATA: LEAD_ID yok"; echo "$LEAD_JSON"; exit 1; }
echo "OK leadId=$LEAD_ID"

echo "==> 2) Deal fetch by lead"
DEAL_JSON="$(curl -sS "$BASE_URL/deals/by-lead/$LEAD_ID" || true)"
DEAL_ID="$(echo "$DEAL_JSON" | json_get "j.id || ''" 2>/dev/null || true)"
if [ -n "${DEAL_ID:-}" ]; then
  echo "OK dealId=$DEAL_ID"
else
  echo "Not: lead create sonrası deal henüz yok; wizard sırasında oluşması bekleniyor."
fi

echo "==> 3) Wizard answer loop (READY_FOR_LISTING hedefi)"
for i in 1 2 3 4 5 6 7 8 9 10; do
  Q="$(curl -fsS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"
  if [ -z "${DEAL_ID:-}" ]; then
    DEAL_ID="$(echo "$Q" | json_get "j.dealId || ''")"
    if [ -n "$DEAL_ID" ]; then
      echo "OK dealId(wizard)=$DEAL_ID"
    fi
  fi
  KEY="$(echo "$Q" | json_get "j.key || ''")"
  FIELD="$(echo "$Q" | json_get "j.field || ''")"
  [ -n "$FIELD" ] || FIELD="$KEY"
  [ -n "$KEY" ] || KEY="$FIELD"

  if [ -z "$FIELD" ]; then
    echo "Wizard done (field yok), loop kırılıyor."
    break
  fi

  A="$(answer_for_field "$FIELD")"
  [ -n "$A" ] || { echo "HATA: field=$FIELD için cevap tanımlı değil"; exit 2; }

  RESP="$(curl -fsS -i -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \
    -H "Content-Type: application/json" \
    -d "{\"key\":\"$KEY\",\"field\":\"$FIELD\",\"answer\":\"$A\"}")"
  CODE="$(echo "$RESP" | http_status)"
  [ "$CODE" = "200" ] || [ "$CODE" = "201" ] || { echo "HATA: wizard/answer code=$CODE"; echo "$RESP"; exit 2; }
done

DEAL_AFTER_WIZ="$(curl -fsS "$BASE_URL/deals/by-lead/$LEAD_ID")"
if [ -z "${DEAL_ID:-}" ]; then
  DEAL_ID="$(echo "$DEAL_AFTER_WIZ" | json_get "j.id || ''")"
fi
STATUS="$(echo "$DEAL_AFTER_WIZ" | json_get "j.status")"
echo "deal.status=$STATUS"
[ -n "$DEAL_ID" ] || { echo "HATA: DEAL_ID yok (wizard sonrası)"; echo "$DEAL_AFTER_WIZ"; exit 3; }
[ "$STATUS" = "READY_FOR_LISTING" ] || [ "$STATUS" = "READY_FOR_MATCHING" ] || { echo "HATA: READY_FOR_LISTING bekleniyordu (legacy READY_FOR_MATCHING de kabul)"; exit 3; }

echo "==> 4) Match deal"
MATCH_RESP="$(curl -fsS -i -X POST "$BASE_URL/deals/$DEAL_ID/match")"
MATCH_CODE="$(echo "$MATCH_RESP" | http_status)"
[ "$MATCH_CODE" = "200" ] || [ "$MATCH_CODE" = "201" ] || { echo "HATA: match code=$MATCH_CODE"; echo "$MATCH_RESP"; exit 4; }
echo "OK match code=$MATCH_CODE"

DEAL_AFTER_MATCH="$(curl -fsS "$BASE_URL/deals/$DEAL_ID")"
CONSULTANT_ID="$(echo "$DEAL_AFTER_MATCH" | json_get "j.consultantId")"
[ -n "$CONSULTANT_ID" ] || { echo "HATA: consultantId boş"; echo "$DEAL_AFTER_MATCH"; exit 4; }
echo "OK consultantId=$CONSULTANT_ID"

echo "==> 5) Inbox pending/mine kontrol"
PENDING="$(curl -fsS -H "$AUTH_HEADER" "$BASE_URL/deals/inbox/pending?take=50&skip=0")"
MINE="$(curl -fsS -H "$AUTH_HEADER" "$BASE_URL/deals/inbox/mine?take=50&skip=0")"

IN_PENDING="$(echo "$PENDING" | json_get "Array.isArray(j) ? j.some(x => x && x.id === '$DEAL_ID') : false")"
IN_MINE="$(echo "$MINE" | json_get "Array.isArray(j) ? j.some(x => x && x.id === '$DEAL_ID') : false")"
echo "pending contains deal: $IN_PENDING"
echo "mine contains deal:    $IN_MINE"
[ "$IN_MINE" = "true" ] || { echo "HATA: deal mine listesinde yok"; exit 5; }

echo "==> 6) Listing upsert from deal (1. çağrı: create beklenir)"
UP1="$(curl -fsS -i -X POST "$BASE_URL/listings/deals/$DEAL_ID/listing" -H "$AUTH_HEADER")"
UP1_CODE="$(echo "$UP1" | http_status)"
UP1_BODY="$(echo "$UP1" | body_only)"
LISTING_ID="$(echo "$UP1_BODY" | json_get "j.id")"
echo "upsert#1 code=$UP1_CODE listingId=$LISTING_ID"
[ "$UP1_CODE" = "201" ] || [ "$UP1_CODE" = "200" ] || { echo "HATA: upsert#1 code=$UP1_CODE"; echo "$UP1"; exit 6; }
[ -n "$LISTING_ID" ] || { echo "HATA: upsert#1 listingId yok"; echo "$UP1_BODY"; exit 6; }

echo "==> 7) Listing upsert from deal (2. çağrı: update/idempotent)"
UP2="$(curl -fsS -i -X POST "$BASE_URL/listings/deals/$DEAL_ID/listing" -H "$AUTH_HEADER")"
UP2_CODE="$(echo "$UP2" | http_status)"
UP2_BODY="$(echo "$UP2" | body_only)"
LISTING_ID_2="$(echo "$UP2_BODY" | json_get "j.id")"
echo "upsert#2 code=$UP2_CODE listingId=$LISTING_ID_2"
[ "$UP2_CODE" = "200" ] || [ "$UP2_CODE" = "201" ] || { echo "HATA: upsert#2 code=$UP2_CODE"; echo "$UP2"; exit 7; }
[ "$LISTING_ID_2" = "$LISTING_ID" ] || { echo "HATA: listing id değişti ($LISTING_ID -> $LISTING_ID_2)"; exit 7; }

echo "==> 8) Deal-link ve listing doğrulama"
DEAL_FINAL="$(curl -fsS "$BASE_URL/deals/$DEAL_ID")"
DEAL_LISTING_ID="$(echo "$DEAL_FINAL" | json_get "j.listingId || ''")"
[ "$DEAL_LISTING_ID" = "$LISTING_ID" ] || { echo "HATA: deal.listingId eşleşmiyor"; echo "$DEAL_FINAL"; exit 8; }

LISTING_FINAL="$(curl -fsS "$BASE_URL/listings/$LISTING_ID")"
LISTING_TITLE="$(echo "$LISTING_FINAL" | json_get "j.title || ''")"
[ -n "$LISTING_TITLE" ] || { echo "HATA: listing title boş"; echo "$LISTING_FINAL"; exit 8; }

echo
echo "✅ SMOKE OK"
echo "leadId=$LEAD_ID"
echo "dealId=$DEAL_ID"
echo "consultantId=$CONSULTANT_ID"
echo "listingId=$LISTING_ID"
