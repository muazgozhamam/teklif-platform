#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
SCHEMA="$ROOT/prisma/schema.prisma"

echo "==> apps/api ROOT=$ROOT"
echo "==> ENV_FILE=$ENV_FILE"
echo "==> SCHEMA=$SCHEMA"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Missing $ENV_FILE (expected apps/api/.env). Put DATABASE_URL there."
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [ -z "${DATABASE_URL:-}" ]; then
  echo "❌ DATABASE_URL missing after loading $ENV_FILE"
  exit 1
fi

# Safety: refuse default dummy/local DB unless explicitly allowed
if echo "$DATABASE_URL" | rg -q "localhost:5432/prisma" && [ "${ALLOW_DUMMY_DB:-0}" != "1" ]; then
  echo "❌ Refusing to run db push: DATABASE_URL looks like the default dummy/local prisma DB."
  echo "   Set a real DATABASE_URL in apps/api/.env, or run with ALLOW_DUMMY_DB=1 if you really mean it."
  exit 1
fi

echo "==> prisma db push"
pnpm -C "$ROOT" exec prisma db push --schema "$SCHEMA"
echo "✅ db push OK"
