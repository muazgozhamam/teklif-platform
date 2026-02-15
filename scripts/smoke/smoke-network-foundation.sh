#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
STAMP="$(date +%s)"
BROKER_EMAIL="${BROKER_EMAIL:-smoke.net.broker.${STAMP}@local.dev}"
HUNTER_EMAIL="${HUNTER_EMAIL:-smoke.net.hunter.${STAMP}@local.dev}"
TEMP_PASSWORD="${TEMP_PASSWORD:-Pass1234!}"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing binary: $1"; exit 2; }
}
need_bin curl
need_bin jq

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

create_user() {
  local token="$1"
  local email="$2"
  local role="$3"
  curl -sS -X POST "$BASE_URL/admin/users" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$TEMP_PASSWORD\",\"role\":\"$role\"}" \
    | jq -r '.id // empty'
}

echo "==> BASE_URL=$BASE_URL"
echo "==> 1) Admin login"
ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }
echo "✅ admin token ready"

echo "==> 2) Create broker + hunter users"
BROKER_ID="$(create_user "$ADMIN_TOKEN" "$BROKER_EMAIL" "BROKER")"
HUNTER_ID="$(create_user "$ADMIN_TOKEN" "$HUNTER_EMAIL" "HUNTER")"
[ -n "$BROKER_ID" ] || { echo "❌ Broker create failed"; exit 1; }
[ -n "$HUNTER_ID" ] || { echo "❌ Hunter create failed"; exit 1; }
echo "✅ created brokerId=$BROKER_ID hunterId=$HUNTER_ID"

echo "==> 3) Set hierarchy hunter -> broker"
SET_PARENT_JSON="$(curl -sS -X POST "$BASE_URL/admin/network/parent" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"childId\":\"$HUNTER_ID\",\"parentId\":\"$BROKER_ID\"}")"
PARENT_ID="$(echo "$SET_PARENT_JSON" | jq -r '.parentId // empty')"
[ "$PARENT_ID" = "$BROKER_ID" ] || { echo "❌ set parent failed"; echo "$SET_PARENT_JSON"; exit 1; }
echo "✅ parent set"

echo "==> 4) Validate path + upline"
PATH_JSON="$(curl -sS "$BASE_URL/admin/network/$HUNTER_ID/path" -H "Authorization: Bearer $ADMIN_TOKEN")"
UPLINE_JSON="$(curl -sS "$BASE_URL/admin/network/$HUNTER_ID/upline?maxDepth=10" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$PATH_JSON" | jq -e --arg hunter "$HUNTER_ID" --arg broker "$BROKER_ID" '. | length >= 2 and .[0].id == $hunter and .[1].id == $broker' >/dev/null \
  || { echo "❌ path validation failed"; echo "$PATH_JSON"; exit 1; }
echo "$UPLINE_JSON" | jq -e --arg broker "$BROKER_ID" '. | length >= 1 and .[0].id == $broker' >/dev/null \
  || { echo "❌ upline validation failed"; echo "$UPLINE_JSON"; exit 1; }
echo "✅ path/upline valid"

echo "==> 5) Set and read commission split"
SPLIT_SET_JSON="$(curl -sS -X POST "$BASE_URL/admin/network/commission-split" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"BROKER","percent":15.5}')"
SPLIT_PERCENT="$(echo "$SPLIT_SET_JSON" | jq -r '.percent // empty')"
[ "$SPLIT_PERCENT" = "15.5" ] || { echo "❌ split set failed"; echo "$SPLIT_SET_JSON"; exit 1; }

SPLIT_MAP_JSON="$(curl -sS "$BASE_URL/admin/network/commission-split" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$SPLIT_MAP_JSON" | jq -e '.BROKER == 15.5' >/dev/null || { echo "❌ split map failed"; echo "$SPLIT_MAP_JSON"; exit 1; }
echo "✅ split map valid"

echo "==> 6) Validate audit entries (raw + canonical)"
AUDIT_PARENT="$(curl -sS "$BASE_URL/admin/audit?action=NETWORK_PARENT_SET&entityType=USER&entityId=$HUNTER_ID&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"
AUDIT_SPLIT="$(curl -sS "$BASE_URL/admin/audit?action=COMMISSION_SPLIT_CONFIG_SET&entityType=COMMISSION_CONFIG&take=20" -H "Authorization: Bearer $ADMIN_TOKEN")"

echo "$AUDIT_PARENT" | jq -e '.items | length > 0 and any(.[]; .action == "NETWORK_PARENT_SET" and .canonicalAction == "NETWORK_PARENT_SET")' >/dev/null \
  || { echo "❌ parent audit missing canonical fields"; echo "$AUDIT_PARENT"; exit 1; }

echo "$AUDIT_SPLIT" | jq -e '.items | length > 0 and any(.[]; .action == "COMMISSION_SPLIT_CONFIG_SET" and .canonicalAction == "COMMISSION_SPLIT_CONFIG_SET")' >/dev/null \
  || { echo "❌ split audit missing canonical fields"; echo "$AUDIT_SPLIT"; exit 1; }
echo "✅ audit checks valid"

echo

echo "✅ SMOKE OK (network foundation)"
echo "brokerId=$BROKER_ID"
echo "hunterId=$HUNTER_ID"
