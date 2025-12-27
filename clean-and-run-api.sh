#!/usr/bin/env bash
set -e

echo "==> Portlar temizleniyor (3000-3003)..."

for PORT in 3000 3001 3002 3003; do
  PID=$(lsof -ti tcp:$PORT || true)
  if [ -n "$PID" ]; then
    echo " - Port $PORT (PID $PID) öldürülüyor"
    kill -9 $PID
  fi
done

echo "==> Sadece API çalıştırılıyor"

cd apps/api

# bazı projelerde dev yerine start:dev olabilir, ikisini de deniyoruz
if pnpm run | grep -q "dev"; then
  pnpm dev
elif pnpm run | grep -q "start:dev"; then
  pnpm start:dev
else
  echo "❌ API için dev script bulunamadı"
  exit 1
fi
