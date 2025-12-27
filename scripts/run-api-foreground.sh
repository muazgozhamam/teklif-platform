#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"

[ -d "$API_DIR" ] || { echo "HATA: apps/api yok"; exit 1; }

echo "==> Port 3001 temizleniyor"
PIDS="$(lsof -ti tcp:3001 || true)"
if [ -n "$PIDS" ]; then
  echo "3001 PID: $PIDS -> kill -9"
  kill -9 $PIDS || true
fi

echo "==> Eski dist temizleniyor"
rm -rf "$API_DIR/dist" 2>/dev/null || true

echo "==> apps/api dev script tespit ediliyor"
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

echo "==> API foreground başlıyor: pnpm -C apps/api run $DEV_SCRIPT (PORT=3001)"
exec bash -lc "cd '$API_DIR' && PORT=3001 NODE_ENV=development DEV_AUTH_BYPASS=1 pnpm run '$DEV_SCRIPT'"
