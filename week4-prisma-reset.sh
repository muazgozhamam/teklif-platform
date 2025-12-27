#!/usr/bin/env bash
set -euo pipefail

cd apps/api

echo "==> prisma migrate reset (DEV) - ALL DATA WILL BE LOST"
# interactive soruyu otomatik "yes" geçmek için:
pnpm prisma migrate reset --force

echo "==> prisma generate"
pnpm prisma generate

echo "==> DONE"
