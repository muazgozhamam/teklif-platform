#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:3001}"
DASHBOARD_URL="${DASHBOARD_URL:-http://localhost:3000}"
RUN_FRONTEND_SIGNOFF="${RUN_FRONTEND_SIGNOFF:-1}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

need_cmd bash

echo "==> smoke-phase3-signoff"
echo "BASE_URL=$BASE_URL"
echo "DASHBOARD_URL=$DASHBOARD_URL"

echo "==> 1) Readiness gate"
BASE_URL="$BASE_URL" DASHBOARD_URL="$DASHBOARD_URL" RUN_FRONTEND_SIGNOFF="$RUN_FRONTEND_SIGNOFF" \
  "$ROOT_DIR/scripts/smoke-phase3-readiness.sh"

echo "==> 2) Optional DB query-plan diag"
if [ -n "${DATABASE_URL:-}" ] && [ -x "$ROOT_DIR/scripts/diag/diag-query-plans.sh" ]; then
  if DATABASE_URL="$DATABASE_URL" "$ROOT_DIR/scripts/diag/diag-query-plans.sh"; then
    echo "✅ diag-query-plans ok"
  else
    echo "⚠️  diag-query-plans warning (skip fail)"
  fi
else
  echo "⚠️  diag-query-plans skipped (DATABASE_URL yok veya script bulunamadi)"
fi

echo "✅ smoke-phase3-signoff OK"
