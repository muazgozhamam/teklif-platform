#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"

echo "==> ROOT: $ROOT_DIR"
echo "==> API : $API_DIR"
echo

if [ ! -d "$API_DIR" ]; then
  echo "HATA: apps/api yok: $API_DIR"
  exit 1
fi

cd "$API_DIR"

# 1) .env yükle (varsa)
if [ -f ".env" ]; then
  echo "==> .env bulundu, environment'a yüklüyorum"
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
else
  echo "HATA: apps/api/.env bulunamadı"
  echo "Beklenen: $API_DIR/.env"
  exit 1
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "HATA: .env yüklendi ama DATABASE_URL hala boş."
  echo "apps/api/.env içinde DATABASE_URL satırını kontrol et."
  exit 1
fi

echo "✅ DATABASE_URL set"
echo

echo "==> Prisma generate"
pnpm -s prisma generate
echo

echo "==> Match Doctor"
cd "$ROOT_DIR"
node "$ROOT_DIR/scripts/_match_doctor.mjs"
echo
echo "✅ DONE"
