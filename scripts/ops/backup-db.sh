#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="${OUT_FILE:-$BACKUP_DIR/teklif-$STAMP.dump}"

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

pick_pg_dump() {
  if [ -n "${PG_DUMP_BIN:-}" ] && [ -x "${PG_DUMP_BIN:-}" ]; then
    printf '%s' "$PG_DUMP_BIN"
    return
  fi
  if [ -x "/opt/homebrew/opt/postgresql@16/bin/pg_dump" ]; then
    printf '%s' "/opt/homebrew/opt/postgresql@16/bin/pg_dump"
    return
  fi
  if command -v pg_dump >/dev/null 2>&1; then
    command -v pg_dump
    return
  fi
  echo "❌ pg_dump not found (set PG_DUMP_BIN or install postgresql@16)" >&2
  exit 1
}

sanitize_database_url() {
  # pg_dump/pg_restore may reject unknown URI params like `schema=public`.
  local url="$1"
  local base query kept first=1
  if [[ "$url" != *"?"* ]]; then
    printf '%s' "$url"
    return
  fi
  base="${url%%\?*}"
  query="${url#*\?}"
  kept=""
  IFS='&' read -r -a parts <<< "$query"
  for kv in "${parts[@]}"; do
    [ -z "$kv" ] && continue
    case "$kv" in
      schema=*|schema%3D*) continue ;;
    esac
    if [ "$first" -eq 1 ]; then
      kept="$kv"
      first=0
    else
      kept="$kept&$kv"
    fi
  done
  if [ -n "$kept" ]; then
    printf '%s?%s' "$base" "$kept"
  else
    printf '%s' "$base"
  fi
}

mkdir -p "$BACKUP_DIR"

echo "==> backup-db"
echo "OUT_FILE=$OUT_FILE"

DB_URL_PG="$(sanitize_database_url "$DATABASE_URL")"
PG_DUMP="$(pick_pg_dump)"
echo "PG_DUMP=$PG_DUMP"
"$PG_DUMP" --format=custom --no-owner --no-privileges --dbname="$DB_URL_PG" --file="$OUT_FILE"

[ -s "$OUT_FILE" ] || { echo "❌ Backup file is empty"; exit 1; }

echo "✅ Backup created: $OUT_FILE"
