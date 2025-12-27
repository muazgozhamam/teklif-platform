#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
echo "==> ROOT: $ROOT"

echo
echo "==> 1) API port 3001 dinliyor mu?"
lsof -nP -iTCP:3001 -sTCP:LISTEN || true

echo
echo "==> 2) Prisma migrate durumu (apps/api)"
cd apps/api

echo "--- prisma validate"
pnpm -s prisma validate || true

echo
echo "--- prisma migrate status"
pnpm -s prisma migrate status || true

echo
echo "--- DB tabloları hızlı kontrol (psql varsa)"
if command -v psql >/dev/null 2>&1; then
  echo "(psql bulundu) public schema tablolar:"
  psql "${DATABASE_URL:-postgresql://localhost:5432/emlak}" -c "\dt" 2>/dev/null || true
else
  echo "psql yok, atlıyorum."
fi

echo
echo "==> 3) /leads çağrısı (verbose) – server response"
cd "$ROOT"
curl -v -X POST http://localhost:3001/leads \
  -H "Content-Type: application/json" \
  -d '{"initialText":"debug lead create"}' \
  2>&1 | tail -n 80 || true

echo
echo "==> 4) Sonuç:"
echo "- Eğer prisma migrate status 'No migration found' diyorsa migrations klasörü yok → lead tabloları DB'de yok olabilir."
echo "- Eğer validate ok ama create 500 ise, Nest logunda Prisma error var demektir."
echo "==> DONE"
