#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"
DIST="$API_DIR/dist"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo

echo "==> 1) dist kilitleyen process var mı? (varsa gösterecek)"
if command -v lsof >/dev/null 2>&1; then
  lsof +D "$DIST" 2>/dev/null || true
else
  echo "lsof yok (skip)"
fi
echo

echo "==> 2) dist'i zorla sil"
# macOS: rm -rf en sağlamı
rm -rf "$DIST"
mkdir -p "$DIST"
echo "✅ dist temiz"
echo

echo "==> 3) build"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
