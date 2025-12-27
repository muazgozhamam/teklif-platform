#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

echo "==> 1) Port temizliği (3000-3003)"
for PORT in 3000 3001 3002 3003; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> $PIDS kill -9"
    kill -9 $PIDS || true
  fi
done

echo "==> 2) Lock/cache temizliği"
rm -f "$ROOT/apps/dashboard/.next/dev/lock" 2>/dev/null || true
rm -f "$ROOT/apps/admin/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/dashboard/.next" 2>/dev/null || true
rm -rf "$ROOT/apps/admin/.next" 2>/dev/null || true
rm -rf "$ROOT/.turbo" 2>/dev/null || true

echo "==> 3) API dev script tespiti"
DEV_SCRIPT="$(node -e "
const p=require(process.cwd()+'/apps/api/package.json');
const s=p.scripts||{};
if (s.dev) process.stdout.write('dev');
else if (s['start:dev']) process.stdout.write('start:dev');
else if (s['dev:watch']) process.stdout.write('dev:watch');
else process.stdout.write('');
")"
if [ -z "$DEV_SCRIPT" ]; then
  echo "HATA: apps/api/package.json içinde dev/start:dev/dev:watch yok."
  node -e "console.log(require(process.cwd()+'/apps/api/package.json').scripts)"
  exit 1
fi
echo "OK: API script -> $DEV_SCRIPT"

echo "==> 4) API'yi arka planda başlat (3001)"
nohup bash -lc "cd '$API_DIR' && PORT=3001 NODE_ENV=development DEV_AUTH_BYPASS=1 pnpm run '$DEV_SCRIPT'" \
  > /tmp/teklif-api.log 2>&1 &

echo "OK: API log -> /tmp/teklif-api.log"

echo "==> 5) API /health bekleniyor..."
for i in {1..60}; do
  if curl -fsS "http://localhost:3001/health" >/dev/null 2>&1; then
    echo "OK: API ayakta (3001)"
    break
  fi
  sleep 0.5
done

if ! curl -fsS "http://localhost:3001/health" >/dev/null 2>&1; then
  echo "HATA: API kalkmadı. Son 120 satır:"
  tail -n 120 /tmp/teklif-api.log || true
  exit 1
fi

echo "==> 6) Admin'i arka planda başlat (turbo filter)"
nohup bash -lc "cd '$ROOT' && pnpm -w turbo dev --filter=@teklif/admin" \
  > /tmp/teklif-admin.log 2>&1 &

echo "OK: Admin log -> /tmp/teklif-admin.log"

echo "==> 7) Admin port bekleniyor (3002)"
for i in {1..60}; do
  if lsof -ti tcp:3002 >/dev/null 2>&1; then
    echo "OK: Admin ayakta (3002)"
    break
  fi
  sleep 0.5
done

if ! lsof -ti tcp:3002 >/dev/null 2>&1; then
  echo "HATA: Admin 3002'de kalkmadı. Son 120 satır:"
  tail -n 120 /tmp/teklif-admin.log || true
  exit 1
fi

echo
echo "=== READY ==="
echo "API:   http://localhost:3001/health"
echo "Admin: http://localhost:3002/admin/users"
