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

auth_login() {
  local email="$1"
  local password="$2"
  curl -fsS -X POST "$BASE_URL/auth/login" \
    -H 'content-type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}"
}

echo "==> diag-observability"
echo "BASE_URL=$BASE_URL"

curl -fsS "$BASE_URL/health" | jq -e '.ok == true' >/dev/null

admin_json="$(auth_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
admin_token="$(echo "$admin_json" | jq -r '.access_token // .accessToken // empty')"
[ -n "$admin_token" ] || { echo "❌ Admin login failed"; exit 1; }

# Generate a small traffic sample.
curl -fsS "$BASE_URL/health" >/dev/null
curl -fsS "$BASE_URL/stats/me" -H "authorization: Bearer $admin_token" >/dev/null
curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/not-found-observability" | grep -q "404"

metrics="$(curl -fsS "$BASE_URL/health/metrics")"
echo "$metrics" | jq -e 'has("requestsTotal") and has("errorsTotal") and has("latencyMs") and has("statusClassCounts") and has("topPaths")' >/dev/null

echo "$metrics" | jq -e '.requestsTotal >= 3' >/dev/null
echo "$metrics" | jq -e '.latencyMs.p95 | numbers' >/dev/null

echo "✅ diag-observability OK"
