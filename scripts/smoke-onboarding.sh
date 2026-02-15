#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-consultant1@test.com}"
CONSULTANT_PASSWORD="${CONSULTANT_PASSWORD:-pass123}"

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

echo "==> smoke-onboarding"
echo "BASE_URL=$BASE_URL"

curl -fsS "$BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }
echo "✅ Admin login ok"

CONS_TOKEN="$(login_token "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD")"
[ -n "$CONS_TOKEN" ] || { echo "❌ Consultant login failed"; exit 1; }
echo "✅ Consultant login ok"

ME_JSON="$(curl -fsS "$BASE_URL/onboarding/me" -H "Authorization: Bearer $CONS_TOKEN")"
echo "$ME_JSON" | jq -e 'has("supported") and has("completionPct") and has("checklist") and has("user")' >/dev/null \
  || { echo "❌ /onboarding/me shape invalid"; exit 1; }
echo "$ME_JSON" | jq -e '.supported == true and (.completionPct|numbers) and (.checklist|type=="array")' >/dev/null \
  || { echo "❌ /onboarding/me values invalid"; exit 1; }
echo "✅ /onboarding/me ok"

ADMIN_JSON="$(curl -fsS "$BASE_URL/admin/onboarding/users?role=CONSULTANT&take=5&skip=0" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$ADMIN_JSON" | jq -e 'has("items") and has("total") and has("take") and has("skip")' >/dev/null \
  || { echo "❌ /admin/onboarding/users shape invalid"; exit 1; }
echo "$ADMIN_JSON" | jq -e '.items|type=="array"' >/dev/null || { echo "❌ /admin/onboarding/users items invalid"; exit 1; }
echo "✅ /admin/onboarding/users ok"

echo "✅ smoke-onboarding OK"
