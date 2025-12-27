#!/usr/bin/env bash
set -e

echo "==> Tüm Nest / Node processleri kapatiliyor"
pkill -f nest || true
pkill -f node || true

echo "==> Turbo / pnpm cache temizleniyor"
rm -rf node_modules/.cache
rm -rf .turbo
rm -rf apps/api/dist
rm -rf apps/api/.nest
rm -rf apps/api/node_modules

echo "==> API bağımlılıkları yeniden kuruluyor"
pnpm --filter api install

echo "==> Prisma generate (tek sefer)"
cd apps/api
npx prisma generate
cd ../..

echo "==> API build"
pnpm --filter api build

echo "==> API PROD modda başlatılıyor (WATCH YOK)"
node apps/api/dist/main.js &

echo "✅ API temiz build ile ayakta"
