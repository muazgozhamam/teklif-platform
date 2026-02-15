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

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

echo "==> smoke-trust"
echo "BASE_URL=$BASE_URL"

curl -fsS "$BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }

LIST_JSON="$(curl -fsS "$BASE_URL/admin/trust/users?take=5&skip=0" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$LIST_JSON" | jq -e 'has("items") and has("total") and has("take") and has("skip")' >/dev/null || { echo "❌ trust list shape invalid"; exit 1; }

echo "$LIST_JSON" | jq -e '.items | length >= 1' >/dev/null || { echo "❌ trust list empty"; exit 1; }

USER_ID="$(echo "$LIST_JSON" | jq -r '.items[0].user.id // empty')"
[ -n "$USER_ID" ] || { echo "❌ trust list user id missing"; exit 1; }

REVIEW_JSON="$(curl -fsS -X POST "$BASE_URL/admin/trust/users/review?userId=$USER_ID" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$REVIEW_JSON" | jq -e '.ok == true and .reviewed == true' >/dev/null || { echo "❌ trust review failed"; exit 1; }

echo "✅ smoke-trust OK"
