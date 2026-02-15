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

echo "==> smoke-gamification"
echo "BASE_URL=$BASE_URL"

curl -fsS "$BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }

CONS_TOKEN="$(login_token "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD")"
[ -n "$CONS_TOKEN" ] || { echo "❌ Consultant login failed"; exit 1; }

ME_JSON="$(curl -fsS "$BASE_URL/gamification/me" -H "Authorization: Bearer $CONS_TOKEN")"
echo "$ME_JSON" | jq -e 'has("points") and has("tier") and has("badges") and has("stats")' >/dev/null || { echo "❌ /gamification/me shape invalid"; exit 1; }

echo "$ME_JSON" | jq -e '.points|numbers' >/dev/null || { echo "❌ /gamification/me points invalid"; exit 1; }

LB_JSON="$(curl -fsS "$BASE_URL/admin/gamification/leaderboard?role=CONSULTANT&take=5&skip=0" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$LB_JSON" | jq -e 'has("items") and has("total") and has("take") and has("skip") and has("role")' >/dev/null || { echo "❌ leaderboard shape invalid"; exit 1; }

echo "$LB_JSON" | jq -e '.role == "CONSULTANT"' >/dev/null || { echo "❌ leaderboard role mismatch"; exit 1; }

echo "✅ smoke-gamification OK"
