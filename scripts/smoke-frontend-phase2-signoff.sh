#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE_URL="${API_BASE_URL:-http://localhost:3001}"
DASHBOARD_BASE_URL="${DASHBOARD_BASE_URL:-http://localhost:3000}"
AUTO_DEV_UP="${AUTO_DEV_UP:-1}"

ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
CONSULTANT_EMAIL="${CONSULTANT_EMAIL:-consultant1@test.com}"
CONSULTANT_PASSWORD="${CONSULTANT_PASSWORD:-pass123}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

need_cmd curl
need_cmd jq

if [ "$AUTO_DEV_UP" = "1" ]; then
  echo "==> start local dev services"
  "$ROOT_DIR/scripts/dev-up.sh"
fi

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

echo "==> smoke-frontend-phase2-signoff"
echo "API_BASE_URL=$API_BASE_URL"
echo "DASHBOARD_BASE_URL=$DASHBOARD_BASE_URL"

curl -fsS "$API_BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }
echo "✅ API health OK"

curl -fsS "$DASHBOARD_BASE_URL/login" >/dev/null || { echo "❌ Dashboard login route failed"; exit 1; }
echo "✅ Dashboard /login OK"

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }

CONS_TOKEN="$(login_token "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD")"
[ -n "$CONS_TOKEN" ] || { echo "❌ Consultant login failed"; exit 1; }

echo "✅ role tokens acquired"

ADMIN_COOKIE="accessToken=$ADMIN_TOKEN"
CONS_COOKIE="accessToken=$CONS_TOKEN"

# Phase 2 route checks
for route in "/admin" "/admin/users" "/admin/audit" "/broker" "/consultant" "/hunter"; do
  status="$(http_status "$DASHBOARD_BASE_URL$route" "$ADMIN_COOKIE")"
  case "$status" in
    200|307|308) echo "✅ route $route status=$status" ;;
    *) echo "❌ route $route unexpected status=$status"; exit 1 ;;
  esac
done

# Listing read model checks (Phase 2 listing improvements)
LISTINGS_API_STATUS="$(http_status "$API_BASE_URL/listings?status=PUBLISHED&page=1&pageSize=12&q=test")"
[ "$LISTINGS_API_STATUS" = "200" ] || { echo "❌ API listings filtered query status=$LISTINGS_API_STATUS"; exit 1; }
echo "✅ API listings filtered query OK"

LISTINGS_UI_STATUS="$(http_status "$DASHBOARD_BASE_URL/listings?status=PUBLISHED&page=1&pageSize=12&q=test")"
[ "$LISTINGS_UI_STATUS" = "200" ] || { echo "❌ Dashboard listings filtered query status=$LISTINGS_UI_STATUS"; exit 1; }
echo "✅ Dashboard listings filtered query OK"

# Workflow handoff check: consultant inbox with dealId query
INBOX_STATUS="$(http_status "$DASHBOARD_BASE_URL/consultant/inbox?dealId=dummy-deal-id&tab=mine" "$CONS_COOKIE")"
case "$INBOX_STATUS" in
  200|307|308) echo "✅ consultant inbox handoff route status=$INBOX_STATUS" ;;
  *) echo "❌ consultant inbox handoff route status=$INBOX_STATUS"; exit 1 ;;
esac

echo "✅ smoke-frontend-phase2-signoff OK"
