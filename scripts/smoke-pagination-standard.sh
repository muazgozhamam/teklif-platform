#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

need_cmd curl
need_cmd jq

echo "==> smoke-pagination-standard"
echo "BASE_URL=$BASE_URL"

health="$(curl -fsS "$BASE_URL/health")"
echo "$health" | jq -e '.ok == true' >/dev/null

auth_login() {
  local email="$1"
  local password="$2"
  curl -fsS -X POST "$BASE_URL/auth/login" \
    -H 'content-type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}"
}

admin_login="$(auth_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")" || {
  echo "❌ Admin login failed"
  exit 1
}
admin_token="$(echo "$admin_login" | jq -r '.accessToken // empty')"
[ -n "$admin_token" ] || { echo "❌ Admin token missing"; exit 1; }
echo "✅ Admin login ok"

stamp="$(date +%s)"
broker_email="pager-broker-$stamp@test.com"
broker_pass='pass123'

curl -fsS -X POST "$BASE_URL/admin/users" \
  -H "authorization: Bearer $admin_token" \
  -H 'content-type: application/json' \
  -d "{\"email\":\"$broker_email\",\"password\":\"$broker_pass\",\"role\":\"BROKER\"}" >/dev/null

echo "✅ Broker test user created"

broker_login="$(auth_login "$broker_email" "$broker_pass")"
broker_token="$(echo "$broker_login" | jq -r '.accessToken // empty')"
[ -n "$broker_token" ] || { echo "❌ Broker token missing"; exit 1; }

echo "✅ Broker login ok"

users_paged="$(curl -fsS "$BASE_URL/admin/users/paged?take=999&skip=-7" -H "authorization: Bearer $admin_token")"
echo "$users_paged" | jq -e 'has("items") and has("total") and has("take") and has("skip")' >/dev/null
echo "$users_paged" | jq -e '.take == 100 and .skip == 0' >/dev/null
echo "✅ /admin/users/paged returns canonical pagination"

broker_pending="$(curl -fsS "$BASE_URL/broker/leads/pending/paged?take=7&skip=0" -H "authorization: Bearer $broker_token")"
echo "$broker_pending" | jq -e 'has("items") and has("total") and has("take") and has("skip") and has("page") and has("limit")' >/dev/null
echo "$broker_pending" | jq -e '.take == 7 and .skip == 0 and .limit == 7' >/dev/null
echo "✅ /broker/leads/pending/paged supports canonical + legacy fields"

listings="$(curl -fsS "$BASE_URL/listings?take=5&skip=0")"
echo "$listings" | jq -e 'has("items") and has("total") and has("take") and has("skip") and has("page") and has("pageSize")' >/dev/null
echo "$listings" | jq -e '.take == 5 and .skip == 0' >/dev/null
echo "✅ /listings supports canonical + legacy fields"

echo "✅ smoke-pagination-standard OK"
