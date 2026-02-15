#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT/apps/api/.env"
SCHEMA="$ROOT/apps/api/prisma/schema.prisma"

echo "==> ROOT=$ROOT"
echo "==> SCHEMA=$SCHEMA"
echo "==> ENV_FILE=$ENV_FILE"

if [ ! -f "$SCHEMA" ]; then
  echo "❌ Missing schema: $SCHEMA"
  exit 1
fi

# apps/api/.env yoksa oluştur (dummy/local)
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<'ENV'
# Local development default (change as needed)
DATABASE_URL="postgresql://prisma:prisma@localhost:5432/prisma?schema=public"
ENV
  echo "✅ Created $ENV_FILE with a default DATABASE_URL (edit if needed)."
else
  echo "✅ Found existing $ENV_FILE"
fi

# .env export (bash 3.2 uyumlu)
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [ -z "${DATABASE_URL:-}" ]; then
  echo "❌ DATABASE_URL still empty after loading $ENV_FILE"
  exit 1
fi

echo "==> Running: pnpm -C apps/api exec prisma generate"
pnpm -C "$ROOT/apps/api" exec prisma generate --schema "$SCHEMA"
echo "✅ prisma generate OK"
