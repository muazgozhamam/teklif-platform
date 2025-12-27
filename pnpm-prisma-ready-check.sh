#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo

cd "$API_DIR"
echo "==> 1) prisma generate (apps/api)"
pnpm -s prisma generate --schema prisma/schema.prisma
echo "✅ generate OK"
echo

cd "$ROOT"
echo "==> 2) .prisma/client/index.d.ts bul (pnpm dahil tüm node_modules)"
FOUND="$(find "$ROOT/node_modules" -type f -path "*/.prisma/client/index.d.ts" 2>/dev/null || true)"

if [[ -z "$FOUND" ]]; then
  echo "❌ .prisma/client/index.d.ts bulunamadı."
  echo "Kontrol için:"
  echo "  find \"$ROOT/node_modules\" -maxdepth 6 -type d -name \".prisma\" -print"
  exit 1
fi

echo "$FOUND"
echo

echo "==> 3) READY_FOR_MATCH var mı?"
HIT=0
while IFS= read -r f; do
  if grep -n "READY_FOR_MATCH" "$f" >/dev/null 2>&1; then
    echo "✅ FOUND in: $f"
    grep -n "READY_FOR_MATCH" "$f" | head -n 10
    HIT=1
  else
    echo "… not in: $f"
  fi
done <<< "$FOUND"

if [[ "$HIT" -ne 1 ]]; then
  echo
  echo "❌ READY_FOR_MATCH hiçbir generated index.d.ts içinde yok."
  echo "Bu durumda schema'da var görünse bile Prisma Client enum'a yansımıyor."
  echo
  echo "Bir sonraki kesin teşhis için şu 3 çıktıyı isteyeceğim:"
  echo "  (1) prisma/schema.prisma içinde enum DealStatus bloğu"
  echo "  (2) model Deal içindeki status satırı"
  echo "  (3) deals.service.ts dosyasında DealStatus import satırı"
  exit 2
fi

echo
echo "==> 4) Build"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
