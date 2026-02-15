#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RESTORE_ON_DRILL="${RESTORE_ON_DRILL:-0}"

if [ -z "${DATABASE_URL:-}" ] && [ -f "$ROOT_DIR/apps/api/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/apps/api/.env"
  set +a
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "❌ DATABASE_URL is required"
  exit 1
fi

echo "==> drill-backup-restore"

"$ROOT_DIR/scripts/ops/backup-db.sh"

LATEST_BACKUP="$(ls -1t "$ROOT_DIR"/backups/*.dump 2>/dev/null | head -n1 || true)"
[ -n "$LATEST_BACKUP" ] || { echo "❌ No backup file found after backup step"; exit 1; }

echo "✅ Latest backup: $LATEST_BACKUP"

if [ "$RESTORE_ON_DRILL" = "1" ]; then
  BACKUP_FILE="$LATEST_BACKUP" "$ROOT_DIR/scripts/ops/restore-db.sh"
  echo "✅ Full restore drill completed"
else
  echo "⚠️  Restore step skipped (set RESTORE_ON_DRILL=1 for full restore drill)"
fi

echo "✅ drill-backup-restore OK"
