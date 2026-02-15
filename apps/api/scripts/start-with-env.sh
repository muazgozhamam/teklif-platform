#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
SCHEMA="$ROOT/prisma/schema.prisma"

echo "==> apps/api ROOT=$ROOT"
echo "==> ENV_FILE=$ENV_FILE"
echo "==> SCHEMA=$SCHEMA"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Missing $ENV_FILE (expected apps/api/.env). Add DATABASE_URL there."
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

# Prod start: generate client to be safe (fast) then start
echo "==> prisma generate"
pnpm -C "$ROOT" exec prisma generate --schema "$SCHEMA"

echo "==> nest start"
pnpm -C "$ROOT" exec nest start
