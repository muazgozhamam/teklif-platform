#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }

echo "==> 1) 3001 dinleyen process var mı? Varsa kill"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
else
  echo "   - 3001 listen eden process yok"
fi

echo
echo "==> 2) Build (dist üret)"
pnpm -s build

echo
echo "==> 3) API'yi dist üzerinden BACKGROUND başlat"
# PORT sabit olsun
export PORT=3001
# Log dosyası
LOG=".tmp-api-dist.log"
rm -f "$LOG"

# Node main dosyası yolunu bul (projeye göre değişebilir)
MAIN=""
if [ -f "dist/src/main.js" ]; then MAIN="dist/src/main.js"; fi
if [ -z "$MAIN" ] && [ -f "dist/main.js" ]; then MAIN="dist/main.js"; fi
if [ -z "$MAIN" ]; then
  echo "HATA: dist içinde main.js bulunamadı. dist/src/main.js veya dist/main.js bekliyordum."
  echo "Kontrol:"
  find dist -maxdepth 3 -name "main.js" -print
  exit 1
fi

node "$MAIN" >"$LOG" 2>&1 &
API_PID=$!
echo "   - API_PID=$API_PID"
echo "   - Log: $LOG"

echo
echo "==> 4) 3001 ayağa kalkmasını bekle (max 5sn) + Health"
for i in 1 2 3 4 5; do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3001/health" | grep -q "200"; then
    break
  fi
  sleep 1
done

echo "Health:"
curl -i "http://localhost:3001/health" || true

echo
echo "==> 5) DEALS advance route var mı testi (route yoksa 'Cannot POST' görürüz)"
curl -i -X POST "http://localhost:3001/deals/test-id/advance" \
  -H "Content-Type: application/json" \
  -d '{"event":"QUESTIONS_COMPLETED"}' || true

echo
echo "==> DONE"
echo "Eğer hala 'Cannot POST /deals/...' görüyorsan, route gerçekten register olmuyor demektir."
echo "Logu paylaş:"
echo "  tail -n 120 $LOG"
echo
echo "API'yi kapatmak için:"
echo "  kill $API_PID"
