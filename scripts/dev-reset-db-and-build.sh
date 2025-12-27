#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"

cd "$API_DIR"

echo "==> prisma migrate reset (FORCE) + generate"
pnpm -s prisma migrate reset --schema prisma/schema.prisma --force

pnpm -s prisma generate --schema prisma/schema.prisma

echo "==> build"
pnpm -s build

echo "✅ DONE: DB reset + migrations applied + build OK"
