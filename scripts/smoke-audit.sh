#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "HATA: '$1' bulunamadı"; exit 2; }
}

need_bin jq

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

echo "==> BASE_URL=$BASE_URL"
echo "==> 1) Run commission won flow (creates lead/deal/listing/won/snapshot)"
FLOW_OUTPUT="$(BASE_URL="$BASE_URL" ./scripts/smoke-commission-won.sh)"
echo "$FLOW_OUTPUT"
DEAL_ID="$(echo "$FLOW_OUTPUT" | awk -F= '/^OK dealId=/{print $2}' | tail -n1 | tr -d '[:space:]')"
[ -n "$DEAL_ID" ] || DEAL_ID="$(echo "$FLOW_OUTPUT" | awk -F= '/^dealId=/{print $2}' | tail -n1 | tr -d '[:space:]')"
[ -n "$DEAL_ID" ] || { echo "HATA: dealId parse edilemedi"; exit 1; }
echo "OK dealId=$DEAL_ID"

echo "==> 2) Admin login"
ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "HATA: admin login başarısız"; exit 1; }
AUTH="Authorization: Bearer $ADMIN_TOKEN"

echo "==> 3) Validate /deals/:id/audit expected actions"
DEAL_AUDIT="$(curl -fsS "$BASE_URL/deals/$DEAL_ID/audit" -H "$AUTH")"
echo "$DEAL_AUDIT" | jq -e '. | length > 0' >/dev/null || { echo "HATA: deal audit boş"; exit 1; }
echo "$DEAL_AUDIT" | jq -e 'map(.action) | index("DEAL_CREATED") != null' >/dev/null || { echo "HATA: DEAL_CREATED yok"; exit 1; }
echo "$DEAL_AUDIT" | jq -e 'map(.action) | index("DEAL_ASSIGNED") != null' >/dev/null || { echo "HATA: DEAL_ASSIGNED yok"; exit 1; }
echo "$DEAL_AUDIT" | jq -e 'map(.action) | index("DEAL_STATUS_CHANGED") != null' >/dev/null || { echo "HATA: DEAL_STATUS_CHANGED yok"; exit 1; }
echo "$DEAL_AUDIT" | jq -e 'map(.action) | index("COMMISSION_SNAPSHOT_CREATED") != null' >/dev/null || { echo "HATA: COMMISSION_SNAPSHOT_CREATED yok"; exit 1; }

LISTING_ID="$(curl -fsS "$BASE_URL/deals/$DEAL_ID" -H "$AUTH" | jq -r '.listingId // empty')"
[ -n "$LISTING_ID" ] || { echo "HATA: deal listingId bulunamadı"; exit 1; }
LISTING_AUDIT="$(curl -fsS "$BASE_URL/listings/$LISTING_ID/audit" -H "$AUTH")"
echo "$LISTING_AUDIT" | jq -e 'map(.action) | index("LISTING_UPSERTED") != null' >/dev/null || { echo "HATA: LISTING_UPSERTED yok"; exit 1; }
echo "OK entity timelines validated"

echo "==> 4) Validate /admin/audit filters"
ADMIN_AUDIT="$(curl -fsS "$BASE_URL/admin/audit?entityType=DEAL&entityId=$DEAL_ID&take=50&skip=0" -H "$AUTH")"
echo "$ADMIN_AUDIT" | jq -e '.total > 0' >/dev/null || { echo "HATA: admin audit total=0"; exit 1; }
echo "$ADMIN_AUDIT" | jq -e --arg id "$DEAL_ID" '.items | any(.entityId == $id)' >/dev/null || { echo "HATA: admin audit item dealId yok"; exit 1; }
echo "OK admin audit filter validated"

echo
echo "✅ SMOKE OK (audit)"
