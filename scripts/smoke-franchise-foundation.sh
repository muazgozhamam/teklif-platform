#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
STAMP="$(date +%s)-$RANDOM"
BROKER_EMAIL="franchise.broker.$STAMP@local.dev"
BROKER_PASS="Pass1234!"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}
need_cmd curl
need_cmd jq

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

admin_call() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  if [ -n "$body" ]; then
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -fsS -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $ADMIN_TOKEN"
  fi
}

echo "==> smoke-franchise-foundation"
echo "BASE_URL=$BASE_URL"

curl -fsS "$BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }
echo "✅ Admin login ok"

BROKER_CREATE="$(admin_call POST /admin/users "{\"email\":\"$BROKER_EMAIL\",\"password\":\"$BROKER_PASS\",\"role\":\"BROKER\"}")"
BROKER_ID="$(echo "$BROKER_CREATE" | jq -r '.id // empty')"
[ -n "$BROKER_ID" ] || { echo "❌ Broker create failed"; exit 1; }

echo "✅ Broker created id=$BROKER_ID"

REGION_JSON="$(admin_call POST /admin/org/regions "{\"city\":\"Istanbul\",\"district\":\"Franchise-$STAMP\"}")"
REGION_ID="$(echo "$REGION_JSON" | jq -r '.id // empty')"
[ -n "$REGION_ID" ] || { echo "❌ Region create failed"; exit 1; }

OFFICE_JSON="$(admin_call POST /admin/org/offices "{\"name\":\"Franchise Office $STAMP\",\"regionId\":\"$REGION_ID\"}")"
OFFICE_ID="$(echo "$OFFICE_JSON" | jq -r '.id // empty')"
[ -n "$OFFICE_ID" ] || { echo "❌ Office create failed"; exit 1; }

ASSIGN_BROKER_JSON="$(admin_call POST "/admin/org/offices/$OFFICE_ID/broker" "{\"brokerId\":\"$BROKER_ID\"}")"
echo "$ASSIGN_BROKER_JSON" | jq -e --arg bid "$BROKER_ID" '.brokerId == $bid' >/dev/null || { echo "❌ Broker assign failed"; exit 1; }

POLICY_JSON="$(admin_call POST "/admin/org/offices/$OFFICE_ID/override-policy" '{"overridePercent":17.5}')"
echo "$POLICY_JSON" | jq -e '.overridePercent == 17.5' >/dev/null || { echo "❌ Override policy set failed"; exit 1; }

SUMMARY_JSON="$(admin_call GET /admin/org/franchise/summary)"
echo "$SUMMARY_JSON" | jq -e 'has("totals") and has("regions") and has("policy")' >/dev/null || { echo "❌ Franchise summary shape invalid"; exit 1; }
echo "$SUMMARY_JSON" | jq -e '.totals.officesWithBroker >= 1 and .totals.officesWithOverridePolicy >= 1' >/dev/null || { echo "❌ Franchise summary totals invalid"; exit 1; }

echo "✅ smoke-franchise-foundation OK"
