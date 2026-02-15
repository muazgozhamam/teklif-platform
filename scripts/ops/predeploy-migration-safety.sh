#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_URL="${BASE_URL:-http://localhost:3001}"
ENV_TARGET="${ENV_TARGET:-local}"  # local|staging|production
ENV_FILE="${ENV_FILE:-apps/api/.env}"
REQUIRE_BACKUP="${REQUIRE_BACKUP:-1}"
BACKUP_MAX_AGE_HOURS="${BACKUP_MAX_AGE_HOURS:-24}"
RUN_SMOKE="${RUN_SMOKE:-1}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}

need_cmd pnpm
need_cmd curl
need_cmd awk
need_cmd date

latest_backup_file() {
  ls -1t "$ROOT_DIR"/backups/*.dump 2>/dev/null | head -n1 || true
}

file_age_hours() {
  local file="$1"
  local now mtime
  now="$(date +%s)"
  if mtime="$(stat -f %m "$file" 2>/dev/null)"; then
    :
  elif mtime="$(stat -c %Y "$file" 2>/dev/null)"; then
    :
  else
    echo "-1"
    return
  fi
  awk -v n="$now" -v m="$mtime" 'BEGIN { printf "%.2f", (n-m)/3600 }'
}

echo "==> predeploy-migration-safety"
echo "ENV_TARGET=$ENV_TARGET"
echo "BASE_URL=$BASE_URL"

echo "==> 1) Env matrix check"
ENV_TARGET="$ENV_TARGET" ENV_FILE="$ENV_FILE" "$ROOT_DIR/scripts/diag/diag-env-matrix.sh"

echo "==> 2) API build + dashboard lint"
pnpm -C "$ROOT_DIR/apps/api" build
pnpm -C "$ROOT_DIR/apps/dashboard" lint

echo "==> 3) Migration status"
MSTATUS="$(pnpm -C "$ROOT_DIR/apps/api" exec prisma migrate status 2>&1 || true)"
echo "$MSTATUS"
if echo "$MSTATUS" | grep -qiE "failed|error|diverged|drift"; then
  echo "❌ Migration status indicates issue"
  exit 1
fi

if echo "$MSTATUS" | grep -qi "pending"; then
  echo "⚠️  Pending migrations detected. Apply with: pnpm -C apps/api exec prisma migrate deploy"
fi

echo "==> 4) Backup freshness"
if [ "$REQUIRE_BACKUP" = "1" ]; then
  LATEST_BACKUP="$(latest_backup_file)"
  if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ No backup file found under $ROOT_DIR/backups"
    exit 1
  fi
  AGE_H="$(file_age_hours "$LATEST_BACKUP")"
  echo "Latest backup: $LATEST_BACKUP"
  echo "Age(hours): $AGE_H"
  if awk -v a="$AGE_H" -v max="$BACKUP_MAX_AGE_HOURS" 'BEGIN { exit !(a >= 0 && a <= max) }'; then
    echo "✅ Backup freshness OK"
  else
    echo "❌ Backup is older than ${BACKUP_MAX_AGE_HOURS}h"
    exit 1
  fi
else
  echo "⚠️  Backup requirement skipped (REQUIRE_BACKUP=0)"
fi

echo "==> 5) Health check"
curl -fsS "$BASE_URL/health" >/dev/null

echo "==> 6) Smoke gate"
if [ "$RUN_SMOKE" = "1" ]; then
  BASE_URL="$BASE_URL" MODE=off "$ROOT_DIR/scripts/smoke/run-api-verification.sh"
else
  echo "⚠️  Smoke gate skipped (RUN_SMOKE=0)"
fi

echo "✅ predeploy-migration-safety OK"
