#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BACKUP_FILE="${BACKUP_FILE:-}"
RESTORE_DROP_CLEAN="${RESTORE_DROP_CLEAN:-0}"

if [ -z "$BACKUP_FILE" ]; then
  echo "❌ BACKUP_FILE is required"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ BACKUP_FILE not found: $BACKUP_FILE"
  exit 1
fi

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

pick_pg_bin() {
  local tool="$1"
  local var_name="$2"
  local explicit="${!var_name:-}"
  if [ -n "$explicit" ] && [ -x "$explicit" ]; then
    printf '%s' "$explicit"
    return
  fi
  if [ -x "/opt/homebrew/opt/postgresql@16/bin/$tool" ]; then
    printf '%s' "/opt/homebrew/opt/postgresql@16/bin/$tool"
    return
  fi
  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return
  fi
  echo "❌ $tool not found (set $var_name or install postgresql@16)" >&2
  exit 1
}

sanitize_database_url() {
  # psql/pg_restore may reject unknown URI params like `schema=public`.
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

DB_URL_PG="$(sanitize_database_url "$DATABASE_URL")"
PG_RESTORE="$(pick_pg_bin pg_restore PG_RESTORE_BIN)"
PSQL_BIN="$(pick_pg_bin psql PSQL_BIN)"

echo "==> restore-db"
echo "BACKUP_FILE=$BACKUP_FILE"
echo "PG_RESTORE=$PG_RESTORE"
echo "PSQL_BIN=$PSQL_BIN"

"$PSQL_BIN" "$DB_URL_PG" -c 'SELECT 1;' >/dev/null

restore_flags=(--no-owner --no-privileges --dbname="$DB_URL_PG")
if [ "$RESTORE_DROP_CLEAN" = "1" ]; then
  restore_flags+=(--clean --if-exists)
fi

"$PG_RESTORE" "${restore_flags[@]}" "$BACKUP_FILE"

echo "✅ Restore completed from: $BACKUP_FILE"
