#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "==> 1) Port temizliği (3000/3001/3002/3003)"
for p in 3000 3001 3002 3003; do
  if lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null 2>&1; then
    echo " - Port $p kill"
    lsof -nP -iTCP:$p -sTCP:LISTEN | awk 'NR>1 {print $2}' | xargs -r kill -9
  else
    echo " - Port $p boş"
  fi
done

echo
echo "==> 2) Next dev lock + cache temizliği"
rm -rf apps/dashboard/.next/dev/lock 2>/dev/null || true
rm -rf apps/dashboard/.next/cache 2>/dev/null || true

echo
echo "==> 3) API dist temizliği"
rm -rf apps/api/dist 2>/dev/null || true

echo
echo "==> DONE: Sistem temiz"
echo
echo "SIRAYLA başlat:"
echo "  1) API   -> cd apps/api && pnpm start:dev"
echo "  2) DASH  -> cd apps/dashboard && pnpm dev"
