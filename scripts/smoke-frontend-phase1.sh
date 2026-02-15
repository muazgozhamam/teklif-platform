#!/usr/bin/env bash
set -euo pipefail

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

login_token() {
  local email="$1"
  local password="$2"
  curl -sS -X POST "$API_BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | jq -r '.access_token // .accessToken // empty'
}

http_status() {
  local url="$1"
  local cookie="${2:-}"
  if [ -n "$cookie" ]; then
    curl -sS -o /dev/null -w "%{http_code}" "$url" -H "Cookie: $cookie"
  else
    curl -sS -o /dev/null -w "%{http_code}" "$url"
  fi
}

echo "==> smoke-frontend-phase1"
echo "API_BASE_URL=$API_BASE_URL"
echo "DASHBOARD_BASE_URL=$DASHBOARD_BASE_URL"

curl -fsS "$API_BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }
echo "✅ API health ok"

LOGIN_STATUS="$(http_status "$DASHBOARD_BASE_URL/login")"
[ "$LOGIN_STATUS" = "200" ] || { echo "❌ /login status=$LOGIN_STATUS"; exit 1; }
echo "✅ Dashboard /login ok"

ADMIN_TOKEN="$(login_token "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
[ -n "$ADMIN_TOKEN" ] || { echo "❌ Admin login failed"; exit 1; }
echo "✅ Admin token acquired"

CONS_TOKEN="$(login_token "$CONSULTANT_EMAIL" "$CONSULTANT_PASSWORD")"
[ -n "$CONS_TOKEN" ] || { echo "❌ Consultant login failed"; exit 1; }
echo "✅ Consultant token acquired"

ADMIN_STATS="$(curl -fsS "$API_BASE_URL/stats/me" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$ADMIN_STATS" | jq -e '.role=="ADMIN"' >/dev/null || { echo "❌ admin /stats/me invalid"; exit 1; }
echo "✅ Admin stats ok"

CONS_STATS="$(curl -fsS "$API_BASE_URL/stats/me" -H "Authorization: Bearer $CONS_TOKEN")"
echo "$CONS_STATS" | jq -e '.role=="CONSULTANT"' >/dev/null || { echo "❌ consultant /stats/me invalid"; exit 1; }
echo "✅ Consultant stats ok"

LISTINGS_STATUS="$(http_status "$API_BASE_URL/listings?status=PUBLISHED")"
[ "$LISTINGS_STATUS" = "200" ] || { echo "❌ API listings status=$LISTINGS_STATUS"; exit 1; }
echo "✅ API listings list ok"

ADMIN_COOKIE="accessToken=$ADMIN_TOKEN"
CONS_COOKIE="accessToken=$CONS_TOKEN"

ADMIN_DASH_STATUS="$(http_status "$DASHBOARD_BASE_URL/admin" "$ADMIN_COOKIE")"
case "$ADMIN_DASH_STATUS" in
  200|307|308) echo "✅ Dashboard /admin status=$ADMIN_DASH_STATUS" ;;
  *) echo "❌ Dashboard /admin unexpected status=$ADMIN_DASH_STATUS"; exit 1 ;;
esac

CONS_DASH_STATUS="$(http_status "$DASHBOARD_BASE_URL/consultant" "$CONS_COOKIE")"
case "$CONS_DASH_STATUS" in
  200|307|308) echo "✅ Dashboard /consultant status=$CONS_DASH_STATUS" ;;
  *) echo "❌ Dashboard /consultant unexpected status=$CONS_DASH_STATUS"; exit 1 ;;
esac

LISTINGS_PAGE_STATUS="$(http_status "$DASHBOARD_BASE_URL/listings")"
[ "$LISTINGS_PAGE_STATUS" = "200" ] || { echo "❌ Dashboard /listings status=$LISTINGS_PAGE_STATUS"; exit 1; }
echo "✅ Dashboard /listings ok"

echo "✅ smoke-frontend-phase1 OK"
