#!/usr/bin/env bash
set -e

API="apps/api/src"

echo "==> 1. @/prisma importlari RELATIVE yapiliyor"
grep -rl "from '@/prisma/prisma.service'" "$API" | while read f; do
  sed -i '' "s|from '@/prisma/prisma.service'|from '../prisma/prisma.service'|g" "$f"
done

echo "==> 2. Prisma beforeExit KALDIRILIYOR"
if [ -f "$API/prisma/prisma.service.ts" ]; then
  sed -i '' '/beforeExit/d' "$API/prisma/prisma.service.ts"
fi

echo "==> 3. \$transaction tx tipleri ekleniyor"
grep -rl "\\$transaction(async (tx)" "$API" | while read f; do
  if ! grep -q "Prisma.TransactionClient" "$f"; then
    sed -i '' "1i\\
import { Prisma } from '@prisma/client';
" "$f"
  fi
  sed -i '' "s/async (tx)/async (tx: Prisma.TransactionClient)/g" "$f"
done

echo "==> 4. Build cache temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> 5. API build"
pnpm --filter api build

echo "✅ API NORMALIZE + BUILD OK"
