#!/usr/bin/env bash
set -euo pipefail

APP_DOMAIN="${APP_DOMAIN:-satdedi.com}"
API_DOMAIN="${API_DOMAIN:-api.satdedi.com}"
HEALTH_PATH="${HEALTH_PATH:-/health}"
EXPECT_HTTPS="${EXPECT_HTTPS:-1}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

print_dns() {
  local host="$1"
  if command -v dig >/dev/null 2>&1; then
    local a_record
    local cname_record
    a_record="$(dig +short A "$host" | tr '\n' ' ' | xargs || true)"
    cname_record="$(dig +short CNAME "$host" | tr '\n' ' ' | xargs || true)"
    echo "ℹ️  DNS $host A: ${a_record:-<none>}"
    echo "ℹ️  DNS $host CNAME: ${cname_record:-<none>}"
  else
    echo "⚠️  dig yok, DNS detay kontrolu atlandi ($host)"
  fi
}

check_url() {
  local url="$1"
  local label="$2"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || true)"

  if [ "$code" = "200" ] || [ "$code" = "204" ]; then
    echo "✅ $label $url status=$code"
  else
    echo "❌ $label $url status=$code"
    return 1
  fi
}

need_cmd curl

echo "==> satdedi-domain-readiness"
echo "APP_DOMAIN=$APP_DOMAIN"
echo "API_DOMAIN=$API_DOMAIN"

echo "==> 1) DNS snapshot"
print_dns "$APP_DOMAIN"
print_dns "$API_DOMAIN"

echo "==> 2) HTTPS checks"
if [ "$EXPECT_HTTPS" = "1" ]; then
  check_url "https://$APP_DOMAIN/login" "Dashboard"
  check_url "https://$API_DOMAIN$HEALTH_PATH" "API health"
else
  check_url "http://$APP_DOMAIN/login" "Dashboard"
  check_url "http://$API_DOMAIN$HEALTH_PATH" "API health"
fi

echo "==> 3) Security headers (best-effort)"
if [ "$EXPECT_HTTPS" = "1" ]; then
  hdrs="$(curl -sSI "https://$APP_DOMAIN/login" || true)"
else
  hdrs="$(curl -sSI "http://$APP_DOMAIN/login" || true)"
fi

echo "$hdrs" | grep -qi "strict-transport-security" && echo "✅ HSTS header var" || echo "⚠️  HSTS header yok"
echo "$hdrs" | grep -qi "x-content-type-options" && echo "✅ X-Content-Type-Options var" || echo "⚠️  X-Content-Type-Options yok"

echo "✅ satdedi-domain-readiness OK"
