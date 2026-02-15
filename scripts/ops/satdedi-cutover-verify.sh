#!/usr/bin/env bash
set -euo pipefail

OLD_APP_DOMAIN="${OLD_APP_DOMAIN:-}"
OLD_API_DOMAIN="${OLD_API_DOMAIN:-}"
NEW_APP_DOMAIN="${NEW_APP_DOMAIN:-satdedi.com}"
NEW_API_DOMAIN="${NEW_API_DOMAIN:-api.satdedi.com}"
USE_HTTPS="${USE_HTTPS:-1}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

scheme() {
  if [ "$USE_HTTPS" = "1" ]; then
    echo "https"
  else
    echo "http"
  fi
}

status_code() {
  local url="$1"
  curl -sS -o /dev/null -w "%{http_code}" "$url" || true
}

assert_good() {
  local code="$1"
  local label="$2"
  if [ "$code" = "200" ] || [ "$code" = "204" ] || [ "$code" = "307" ] || [ "$code" = "308" ]; then
    echo "✅ $label status=$code"
  else
    echo "❌ $label status=$code"
    return 1
  fi
}

need_cmd curl
SCHEME="$(scheme)"

echo "==> satdedi-cutover-verify"
echo "NEW_APP_DOMAIN=$NEW_APP_DOMAIN"
echo "NEW_API_DOMAIN=$NEW_API_DOMAIN"

echo "==> 1) New domains health"
NEW_LOGIN_CODE="$(status_code "$SCHEME://$NEW_APP_DOMAIN/login")"
NEW_HEALTH_CODE="$(status_code "$SCHEME://$NEW_API_DOMAIN/health")"
assert_good "$NEW_LOGIN_CODE" "new app /login"
assert_good "$NEW_HEALTH_CODE" "new api /health"

if [ -n "$OLD_APP_DOMAIN" ]; then
  echo "==> 2) Old app domain behavior"
  OLD_APP_CODE="$(status_code "$SCHEME://$OLD_APP_DOMAIN/login")"
  echo "ℹ️  old app /login status=$OLD_APP_CODE"
fi

if [ -n "$OLD_API_DOMAIN" ]; then
  echo "==> 3) Old api domain behavior"
  OLD_API_CODE="$(status_code "$SCHEME://$OLD_API_DOMAIN/health")"
  echo "ℹ️  old api /health status=$OLD_API_CODE"
fi

echo "✅ satdedi-cutover-verify OK"
