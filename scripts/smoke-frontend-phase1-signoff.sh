#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE_URL="${API_BASE_URL:-http://localhost:3001}"
DASHBOARD_BASE_URL="${DASHBOARD_BASE_URL:-http://localhost:3000}"
AUTO_DEV_UP="${AUTO_DEV_UP:-1}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

need_cmd curl
need_cmd bash

if [ "$AUTO_DEV_UP" = "1" ]; then
  echo "==> start local dev services"
  "$ROOT_DIR/scripts/dev-up.sh"
fi

echo "==> frontend phase1 signoff"
echo "API_BASE_URL=$API_BASE_URL"
echo "DASHBOARD_BASE_URL=$DASHBOARD_BASE_URL"

curl -fsS "$API_BASE_URL/health" >/dev/null || { echo "❌ API health failed"; exit 1; }
echo "✅ API health OK"

curl -fsS "$DASHBOARD_BASE_URL/login" >/dev/null || { echo "❌ Dashboard login route failed"; exit 1; }
echo "✅ Dashboard route OK"

API_BASE_URL="$API_BASE_URL" DASHBOARD_BASE_URL="$DASHBOARD_BASE_URL" "$ROOT_DIR/scripts/smoke-frontend-phase1.sh"

echo "✅ Frontend Phase 1 signoff OK"
