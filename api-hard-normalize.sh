#!/usr/bin/env bash
set -e

API="apps/api/src"

echo "==> 1. @/prisma importlari RELATIVE yapiliyor"
grep -rl "from '@/prisma/prisma.service'" "$API" | while read f; do
  sed -i '' "s@from '@/prisma/prisma.service'@from '../prisma/prisma.service'@g" "$f"
done

echo "==> 2. rates gibi yan klasorler icin relative duzeltme"
sed -i '' "s@from '../prisma/prisma.service'@from '../prisma/prisma.service'@g" \
  "$API/rates/rate.service.ts" 2>/dev/null || true

echo "==> 3. Prisma beforeExit KALDIRILIYOR"
sed -i '' "/beforeExit/d" "$API/prisma/prisma.service.ts"

echo "==> 4. \$transaction tx tipleri ekleniyor"
grep -rl "\\$transaction(async (tx)" "$API" | while read f; do
  if ! grep -q "Prisma.TransactionClient" "$f"; then
    sed -i '' "1s/^/import { Prisma } from '@prisma\\/client';\n/" "$f"
  fi
  sed -i '' "s/async (tx)/async (tx: Prisma.TransactionClient)/g" "$f"
done

echo "==> 5. Build cache temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> 6. API build"
pnpm --filter api build

echo "✅ API NORMALIZE + BUILD OK"
