#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE_URL="${API_BASE_URL:-http://localhost:3001}"
DASHBOARD_BASE_URL="${DASHBOARD_BASE_URL:-http://localhost:3000}"

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-consultant1@test.com}"
CONSULTANT_PASSWORD="${CONSULTANT_PASSWORD:-pass123}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

need_cmd curl
need_cmd jq

http_status() {
  local url="$1"
  local cookie="${2:-}"
  if [ -n "$cookie" ]; then
    curl -sS -o /dev/null -w "%{http_code}" "$url" -H "Cookie: $cookie"
  else
    curl -sS -o /dev/null -w "%{http_code}" "$url"
  fi
}

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$API_BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

assert_dashboard_ok() {
  local path="$1"
  local cookie="${2:-}"
  local code
  code="$(http_status "$DASHBOARD_BASE_URL$path" "$cookie")"
  case "$code" in
    200|307|308) echo "✅ $path status=$code" ;;
    *) echo "❌ $path unexpected status=$code"; exit 1 ;;
  esac
}

echo "==> smoke-frontend-phase2-signoff"
echo "API_BASE_URL=$API_BASE_URL"
echo "DASHBOARD_BASE_URL=$DASHBOARD_BASE_URL"

curl -fsS "$API_BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }
echo "✅ API health ok"

LOGIN_STATUS="$(http_status "$DASHBOARD_BASE_URL/login")"
[ "$LOGIN_STATUS" = "200" ] || { echo "❌ /login status=$LOGIN_STATUS"; exit 1; }
echo "✅ /login status=200"

"$ROOT_DIR/scripts/smoke-frontend-phase1.sh"
echo "✅ Phase 1 smoke dependency ok"

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }
CONS_TOKEN="$(login_token "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD")"
[ -n "$CONS_TOKEN" ] || { echo "❌ Consultant login failed"; exit 1; }

ADMIN_COOKIE="accessToken=$ADMIN_TOKEN"
CONS_COOKIE="accessToken=$CONS_TOKEN"

assert_dashboard_ok "/admin" "$ADMIN_COOKIE"
assert_dashboard_ok "/admin/users" "$ADMIN_COOKIE"
assert_dashboard_ok "/admin/audit" "$ADMIN_COOKIE"
assert_dashboard_ok "/broker" "$ADMIN_COOKIE"
assert_dashboard_ok "/consultant" "$CONS_COOKIE"
assert_dashboard_ok "/consultant/inbox" "$CONS_COOKIE"
assert_dashboard_ok "/listings"

echo "✅ smoke-frontend-phase2-signoff OK"
