#!/usr/bin/env bash
set -euo pipefail

APP_DOMAIN="${APP_DOMAIN:-satdedi.com}"
API_DOMAIN="${API_DOMAIN:-api.satdedi.com}"
USE_HTTPS="${USE_HTTPS:-1}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@local.dev}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

base_scheme() {
  if [ "$USE_HTTPS" = "1" ]; then
    echo "https"
  else
    echo "http"
  fi
}

http_status() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "$url" || true
}

assert_ok_status() {
  local url="$1"
  local label="$2"
  local code
  code="$(http_status "$url")"
  case "$code" in
    200|204|307|308)
      echo "✅ $label status=$code"
      ;;
    *)
      echo "❌ $label status=$code"
      return 1
      ;;
  esac
}

need_cmd curl
need_cmd jq

SCHEME="$(base_scheme)"
APP_BASE="$SCHEME://$APP_DOMAIN"
API_BASE="$SCHEME://$API_DOMAIN"

echo "==> satdedi-post-go-live-smoke"
echo "APP_BASE=$APP_BASE"
echo "API_BASE=$API_BASE"

echo "==> 1) Public routes"
assert_ok_status "$APP_BASE/login" "Dashboard /login"
assert_ok_status "$APP_BASE/listings" "Dashboard /listings"

echo "==> 2) API liveness"
assert_ok_status "$API_BASE/health" "API /health"

METRICS_CODE="$(http_status "$API_BASE/health/metrics")"
if [ "$METRICS_CODE" = "200" ] || [ "$METRICS_CODE" = "401" ] || [ "$METRICS_CODE" = "403" ]; then
  echo "✅ API /health/metrics reachable status=$METRICS_CODE"
else
  echo "⚠️  API /health/metrics unexpected status=$METRICS_CODE"
fi

echo "==> 3) Auth + protected route"
LOGIN_JSON="$(curl -sS -X POST "$API_BASE/auth/login" -H "Content-Type: application/json" -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")"
ADMIN_TOKEN="$(echo "$LOGIN_JSON" | jq -r '.access_token // .accessToken // empty')"
if [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Admin login failed on go-live endpoint"
  exit 1
fi
echo "✅ Admin login ok"

STATS_JSON="$(curl -fsS "$API_BASE/stats/me" -H "Authorization: Bearer $ADMIN_TOKEN")"
echo "$STATS_JSON" | jq -e '.role == "ADMIN"' >/dev/null || { echo "❌ /stats/me role validation failed"; exit 1; }
echo "✅ /stats/me role=ADMIN"

echo "✅ satdedi-post-go-live-smoke OK"
