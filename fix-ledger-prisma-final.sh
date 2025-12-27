#!/usr/bin/env bash
set -e

echo "==> Prisma schema force non-null yapiliyor"

SCHEMA="apps/api/prisma/schema.prisma"

perl -0777 -i -pe '
s/commission\s+Float\??/commission Float/g;
s/net\s+Float\??/net Float/g;
' "$SCHEMA"

echo "==> Prisma migrate (force_non_null_commission)"

cd apps/api
npx prisma migrate dev --name force_non_null_commission --skip-seed

echo "==> Prisma client regenerate"
npx prisma generate

echo "==> Eski Nest process kapatiliyor"
pkill -f nest || true

echo "==> API yeniden baslatiliyor"
cd ../..
pnpm --filter api start:dev &

echo "✅ TAMAM: Ledger artik NULL yazamaz"
