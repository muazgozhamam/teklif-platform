#!/usr/bin/env bash
set -e

API="apps/api/src"

echo "==> 1) @/prisma importlarini relative yapiyorum"

grep -R "@\/prisma\/prisma.service" "$API" -l | while read -r f; do
  sed -i '' 's@from "@/prisma/prisma.service"@from "../prisma/prisma.service"@g' "$f"
done

echo "==> 2) Prisma transaction tx type fix (any -> typed)"

grep -R "\$transaction" "$API" -l | while read -r f; do
  sed -i '' 's/async (tx)/async (tx: Prisma.TransactionClient)/g' "$f"

  if ! grep -q "Prisma.TransactionClient" "$f"; then
    sed -i '' 's/import { PrismaService }/import { Prisma, PrismaService }/g' "$f"
  fi
done

echo "==> 3) Dist ve Nest cache temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> 4) API build"
pnpm --filter api build

echo "==> 5) API baslatiliyor"
node apps/api/dist/main.js &

echo "✅ BITTI: API DERLENDI VE AYAKTA"
