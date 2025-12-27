#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"

echo "==> ROOT: $ROOT_DIR"
echo "==> API : $API_DIR"
echo

if [ ! -d "$API_DIR" ]; then
  echo "HATA: apps/api bulunamadı: $API_DIR"
  exit 1
fi

cd "$API_DIR"

echo "==> DATABASE_URL kontrol"
if [ -z "${DATABASE_URL:-}" ]; then
  echo "HATA: DATABASE_URL environment'ta yok."
  echo "ÇÖZÜM (apps/api içinde):"
  echo "  set -a; source ./.env; set +a"
  echo "Sonra tekrar:"
  echo "  cd $ROOT_DIR && bash ./scripts/match-doctor.sh"
  exit 1
fi
echo "OK: DATABASE_URL set"
echo

echo "==> Prisma generate"
pnpm -s prisma generate
echo

echo "==> Match Doctor"
node "$ROOT_DIR/scripts/_match_doctor.mjs"
