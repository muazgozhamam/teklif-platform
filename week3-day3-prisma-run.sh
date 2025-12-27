#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

if [ ! -d "$API_DIR" ]; then
  echo "ERROR: apps/api yok. Proje kökünde misin?"
  exit 1
fi

echo "==> Running Prisma via pnpm exec in apps/api"

cd "$API_DIR"

# Prisma binary var mı?
if ! pnpm exec prisma -v >/dev/null 2>&1; then
  echo "==> Prisma CLI bulunamadı. api paketine ekliyorum..."
  pnpm add -D prisma
  pnpm add @prisma/client
fi

pnpm exec prisma migrate dev --name add_offer
pnpm exec prisma generate

echo "==> Prisma migrate+generate OK"
