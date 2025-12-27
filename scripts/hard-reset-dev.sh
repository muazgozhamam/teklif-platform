#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "==> 1) Port temizliği (3000-3003)"
for PORT in 3000 3001 3002 3003; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> $PIDS kill -9"
    kill -9 $PIDS || true
  fi
done

echo "==> 2) Node/Next lock ve cache temizliği"
rm -f "$ROOT/apps/dashboard/.next/dev/lock" 2>/dev/null || true
rm -f "$ROOT/apps/admin/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/admin/.next" 2>/dev/null || true
rm -rf "$ROOT/apps/dashboard/.next" 2>/dev/null || true

echo "==> 3) Turbo cache temizliği"
rm -rf "$ROOT/.turbo" 2>/dev/null || true

echo "==> 4) API derleyici watch süreçleri (tsc/nest) kalmışsa öldür"
pkill -f "nest start" 2>/dev/null || true
pkill -f "tsc -w" 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "turbopack" 2>/dev/null || true
pkill -f "turbo dev" 2>/dev/null || true

echo "==> OK: ortam sıfırlandı."
echo
echo "Şimdi sadece API + ADMIN başlat:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
