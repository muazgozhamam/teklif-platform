#!/usr/bin/env bash
set -e

echo "==> API temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> API build"
pnpm --filter api build

echo "==> API baslatiliyor"
node apps/api/dist/main.js &

echo "✅ API TAMAMEN AYAKTA"
