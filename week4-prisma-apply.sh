#!/usr/bin/env bash
set -euo pipefail
cd apps/api

echo "==> prisma migrate status"
pnpm prisma migrate status

echo
echo "==> prisma migrate dev (apply any pending migrations)"
pnpm prisma migrate dev

echo
echo "==> prisma generate"
pnpm prisma generate

echo "==> DONE"
