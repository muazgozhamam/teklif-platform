#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DOMAIN="${APP_DOMAIN:-satdedi.com}"
API_DOMAIN="${API_DOMAIN:-api.satdedi.com}"
BASE_URL="${BASE_URL:-https://$API_DOMAIN}"
DASHBOARD_URL="${DASHBOARD_URL:-https://$APP_DOMAIN}"
RUN_FRONTEND_SIGNOFF="${RUN_FRONTEND_SIGNOFF:-1}"

need_exec() {
  local file="$1"
  if [ ! -x "$file" ]; then
    echo "❌ Missing executable: $file"
    exit 1
  fi
}

echo "==> satdedi-release-day"
echo "APP_DOMAIN=$APP_DOMAIN"
echo "API_DOMAIN=$API_DOMAIN"
echo "BASE_URL=$BASE_URL"
echo "DASHBOARD_URL=$DASHBOARD_URL"

echo "==> 1) Phase 3 signoff"
need_exec "$ROOT_DIR/scripts/smoke-phase3-signoff.sh"
BASE_URL="$BASE_URL" DASHBOARD_URL="$DASHBOARD_URL" RUN_FRONTEND_SIGNOFF="$RUN_FRONTEND_SIGNOFF" \
  "$ROOT_DIR/scripts/smoke-phase3-signoff.sh"

echo "==> 2) Domain readiness"
need_exec "$ROOT_DIR/scripts/ops/satdedi-domain-readiness.sh"
APP_DOMAIN="$APP_DOMAIN" API_DOMAIN="$API_DOMAIN" "$ROOT_DIR/scripts/ops/satdedi-domain-readiness.sh"

echo "==> 3) Post go-live smoke"
need_exec "$ROOT_DIR/scripts/ops/satdedi-post-go-live-smoke.sh"
APP_DOMAIN="$APP_DOMAIN" API_DOMAIN="$API_DOMAIN" "$ROOT_DIR/scripts/ops/satdedi-post-go-live-smoke.sh"

echo "✅ satdedi-release-day OK"
