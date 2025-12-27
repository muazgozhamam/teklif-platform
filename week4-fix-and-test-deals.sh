#!/usr/bin/env bash
set -euo pipefail

API_DIR="apps/api"

echo "==> 1) Prisma generate (Deal modelini PrismaClient'a getir)"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma

echo
echo "==> 2) Build (hata varsa ekrana bas)"
if pnpm build 2>&1 | tee /tmp/api-build.log; then
  echo "✅ build OK"
else
  echo "❌ build FAIL. Log: /tmp/api-build.log"
  exit 1
fi

echo
echo "==> 3) Hatırlatma: dev server restart şart"
echo "Şimdi diğer terminalde çalışan pnpm start:dev varsa CTRL+C ile durdur, sonra:"
echo "  cd apps/api && pnpm start:dev"
echo
echo "==> 4) Server ayaktaysa endpoint smoke test"
echo "  curl -i http://localhost:3001/health"
echo "  curl -i http://localhost:3001/docs"
echo "  curl -i http://localhost:3001/deals/by-lead/TEST"
