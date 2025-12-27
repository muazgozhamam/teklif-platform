#!/usr/bin/env bash
set -euo pipefail

API_DIR="$(pwd)/apps/api"

echo "==> API build kontrol: $API_DIR"
cd "$API_DIR"

# watch yerine tek sefer build (hata varsa burada kesin çıkar)
pnpm -s build

echo "✅ BUILD OK"
