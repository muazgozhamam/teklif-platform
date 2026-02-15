#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:3001}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:3000}"
API_ENV_FILE="${API_ENV_FILE:-$ROOT_DIR/apps/api/.env}"
DASHBOARD_ENV_FILE="${DASHBOARD_ENV_FILE:-$ROOT_DIR/apps/dashboard/.env.local}"
RUN_FRONTEND_SIGNOFF="${RUN_FRONTEND_SIGNOFF:-0}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

check_env_key() {
  local file="$1"
  local key="$2"
  if [ ! -f "$file" ]; then
    echo "⚠️  Env file not found: $file"
    return 0
  fi
  if grep -Eq "^${key}=" "$file"; then
    echo "✅ $key found in $(basename "$file")"
  else
    echo "⚠️  $key missing in $(basename "$file")"
  fi
}

need_cmd curl
need_cmd pnpm

echo "==> phase3-readiness"
echo "BASE_URL=$BASE_URL"
echo "DASHBOARD_URL=$DASHBOARD_URL"

echo "==> 1) API health"
curl -fsS "$BASE_URL/health" >/dev/null
echo "✅ API health ok"

echo "==> 2) Dashboard route health"
code="$(curl -sS -o /dev/null -w "%{http_code}" "$DASHBOARD_URL/login")"
if [ "$code" != "200" ] && [ "$code" != "307" ] && [ "$code" != "308" ]; then
  echo "❌ Dashboard /login status=$code"
  exit 1
fi
echo "✅ Dashboard /login status=$code"

echo "==> 3) Env matrix quick check"
check_env_key "$API_ENV_FILE" "DATABASE_URL"
check_env_key "$API_ENV_FILE" "JWT_SECRET"
check_env_key "$API_ENV_FILE" "JWT_REFRESH_SECRET"
check_env_key "$DASHBOARD_ENV_FILE" "NEXT_PUBLIC_API_BASE_URL"

echo "==> 4) Build/lint gates"
pnpm -C "$ROOT_DIR/apps/api" build
pnpm -C "$ROOT_DIR/apps/dashboard" lint
pnpm -C "$ROOT_DIR/apps/dashboard" exec next build --webpack

echo "==> 5) Optional frontend signoff"
if [ "$RUN_FRONTEND_SIGNOFF" = "1" ]; then
  if [ -x "$ROOT_DIR/scripts/smoke-frontend-phase2-signoff.sh" ]; then
    API_BASE_URL="$BASE_URL" DASHBOARD_BASE_URL="$DASHBOARD_URL" "$ROOT_DIR/scripts/smoke-frontend-phase2-signoff.sh"
  else
    echo "⚠️  scripts/smoke-frontend-phase2-signoff.sh not found, skip"
  fi
else
  echo "⚠️  skip frontend signoff (set RUN_FRONTEND_SIGNOFF=1 to enable)"
fi

echo "✅ phase3-readiness OK"
