#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

BASE_URL="${BASE_URL:-http://localhost:3001}"
LOG=".tmp/api-dev-3001.log"

echo "==> ROOT: $(pwd)"
echo "==> BASE_URL=$BASE_URL"
echo "==> LOG=$LOG"

echo
echo "==> 1) 3001 portunu boşalt"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
else
  echo "   - 3001 boş"
fi

echo
echo "==> 2) API build (hızlı doğrulama)"
cd apps/api
pnpm -s build
cd ~/Desktop/teklif-platform

echo
echo "==> 3) DEV server başlat (background) + log"
mkdir -p .tmp
rm -f "$LOG"
( cd apps/api && pnpm -s start:dev ) >"$LOG" 2>&1 &
API_PID=$!
echo "   - API_PID=$API_PID"

echo
echo "==> 4) Health check (max 30 sn)"
for i in $(seq 1 30); do
  if curl -sS "$BASE_URL/health" >/dev/null 2>&1; then
    echo "✅ OK: API up at $BASE_URL (attempt $i)"
    echo "   - Tail log:"
    tail -n 30 "$LOG" || true
    exit 0
  fi
  sleep 1
done

echo "ERR: API did not become healthy in time."
echo "Last 80 lines of log:"
tail -n 80 "$LOG" || true
exit 1
