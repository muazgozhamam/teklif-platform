#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing binary: $1"; exit 2; }; }
need_bin curl
need_bin jq

echo "==> smoke-auth-refresh"
echo "BASE_URL=$BASE_URL"

login_json="$(curl -fsS -X POST "$BASE_URL/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")"
access_token="$(echo "$login_json" | jq -r '.access_token // empty')"
refresh_token="$(echo "$login_json" | jq -r '.refresh_token // empty')"
[ -n "$access_token" ] || { echo "❌ access_token missing"; exit 1; }
[ -n "$refresh_token" ] || { echo "❌ refresh_token missing"; exit 1; }
echo "✅ login returned access+refresh tokens"

refresh_json="$(curl -fsS -X POST "$BASE_URL/auth/refresh" -H 'Content-Type: application/json' -d "{\"refresh_token\":\"$refresh_token\"}")"
new_access_token="$(echo "$refresh_json" | jq -r '.access_token // empty')"
new_refresh_token="$(echo "$refresh_json" | jq -r '.refresh_token // empty')"
[ -n "$new_access_token" ] || { echo "❌ refreshed access_token missing"; exit 1; }
[ -n "$new_refresh_token" ] || { echo "❌ refreshed refresh_token missing"; exit 1; }
echo "✅ refresh endpoint returned new tokens"

me_json="$(curl -fsS "$BASE_URL/auth/me" -H "Authorization: Bearer $new_access_token")"
echo "$me_json" | jq -e '.sub != null and .role != null' >/dev/null || { echo "❌ refreshed access token invalid for /auth/me"; exit 1; }

echo "✅ auth/me works with refreshed access token"
echo "✅ smoke-auth-refresh OK"
