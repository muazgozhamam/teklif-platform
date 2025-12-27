#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/Desktop/teklif-platform"
API_DIR="$ROOT/apps/api"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo

cd "$API_DIR"

echo "==> 1) prisma generate (schema net)"
pnpm -s prisma generate --schema prisma/schema.prisma
echo "✅ generate OK"
echo

echo "==> 2) .prisma/client dizinlerini bul"
cd "$ROOT"
# pnpm/monorepo yüzünden birden fazla olabilir; hepsini listeleyelim
FOUND=$(find "$ROOT" -maxdepth 4 -type f -path "*/node_modules/.prisma/client/index.d.ts" 2>/dev/null || true)
if [[ -z "$FOUND" ]]; then
  echo "❌ node_modules/.prisma/client/index.d.ts bulunamadı."
  echo "Kontrol:"
  find "$ROOT" -maxdepth 4 -type d -name ".prisma" -print
  exit 1
fi

echo "$FOUND"
echo

echo "==> 3) READY_FOR_MATCH var mı? (asıl doğru kontrol burası)"
HIT=0
while IFS= read -r f; do
  if grep -n "READY_FOR_MATCH" "$f" >/dev/null 2>&1; then
    echo "✅ FOUND in: $f"
    grep -n "READY_FOR_MATCH" "$f" | head -n 5
    HIT=1
  else
    echo "… not in: $f"
  fi
done <<< "$FOUND"

if [[ "$HIT" -ne 1 ]]; then
  echo
  echo "❌ READY_FOR_MATCH hiçbir generated index.d.ts içinde yok."
  echo "Bu durumda schema'da görünse bile client'a yansımıyor demek."
  echo "Sonraki teşhis: DealStatus enum gerçekten model field'ında kullanılıyor mu?"
  exit 2
fi

echo
echo "==> 4) Build"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"
