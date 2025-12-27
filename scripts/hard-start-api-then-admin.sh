#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

echo "==> 0) Root kontrol"
[ -d "$API_DIR" ] || { echo "HATA: apps/api yok"; exit 1; }

echo "==> 1) Port temizliği (3000-3003,3011)"
for PORT in 3000 3001 3002 3003 3011; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> $PIDS kill -9"
    kill -9 $PIDS || true
  fi
done

echo "==> 2) Next/Turbo lock temizliği"
rm -f "$ROOT/apps/dashboard/.next/dev/lock" 2>/dev/null || true
rm -f "$ROOT/apps/admin/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/dashboard/.next" 2>/dev/null || true
rm -rf "$ROOT/apps/admin/.next" 2>/dev/null || true
rm -rf "$ROOT/.turbo" 2>/dev/null || true

echo "==> 3) API'yi 3001'de başlat (standalone)"
# apps/api/package.json içinden uygun dev scriptini seç
DEV_SCRIPT="$(node -e "
const p=require(process.cwd()+'/apps/api/package.json');
const s=p.scripts||{};
if (s.dev) process.stdout.write('dev');
else if (s['start:dev']) process.stdout.write('start:dev');
else if (s['dev:watch']) process.stdout.write('dev:watch');
else process.stdout.write('');
")"

if [ -z "$DEV_SCRIPT" ]; then
  echo "HATA: apps/api/package.json içinde dev veya start:dev script'i yok."
  node -e "console.log(require(process.cwd()+'/apps/api/package.json').scripts)"
  exit 1
fi

echo "OK: API script -> $DEV_SCRIPT"
echo "API log: /tmp/teklif-api.log"

# API’yi arka planda çalıştır
( cd "$API_DIR" && PORT=3001 NODE_ENV=development DEV_AUTH_BYPASS=1 pnpm run "$DEV_SCRIPT" ) \
  > /tmp/teklif-api.log 2>&1 &

API_PID=$!
echo "OK: API PID=$API_PID"

echo "==> 4) /health bekleniyor..."
for i in {1..40}; do
  if curl -fsS "http://localhost:3001/health" >/dev/null 2>&1; then
    echo "OK: API ayakta -> http://localhost:3001/health"
    break
  fi
  sleep 0.5
done

if ! curl -fsS "http://localhost:3001/health" >/dev/null 2>&1; then
  echo "HATA: API kalkmadı. Son 120 satır log:"
  tail -n 120 /tmp/teklif-api.log || true
  echo
  echo "Tam log: /tmp/teklif-api.log"
  exit 1
fi

echo "==> 5) Admin'i başlat"
pnpm -w turbo dev --filter=@teklif/admin
