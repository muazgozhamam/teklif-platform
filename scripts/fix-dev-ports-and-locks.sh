#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
DASH_LOCK="$ROOT/apps/dashboard/.next/dev/lock"

echo "==> 3001 (api) ve 3002 (dashboard) port temizliği"

kill_port () {
  local PORT="$1"
  local PIDS
  PIDS="$(lsof -ti tcp:"$PORT" || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> PID(ler): $PIDS kapatılıyor"
    # önce nazikçe
    kill $PIDS || true
    sleep 1
    # hala duruyorsa force
    PIDS="$(lsof -ti tcp:"$PORT" || true)"
    if [ -n "$PIDS" ]; then
      echo "Port $PORT -> PID(ler) zorla kapatılıyor: $PIDS"
      kill -9 $PIDS || true
    fi
  else
    echo "Port $PORT boş"
  fi
}

kill_port 3001
kill_port 3002
kill_port 3000

echo "==> Next dev lock temizliği"
if [ -f "$DASH_LOCK" ]; then
  rm -f "$DASH_LOCK"
  echo "Silindi: $DASH_LOCK"
else
  echo "Lock yok"
fi

echo "==> Tamam. Şimdi root'ta dev başlat:"
echo "pnpm dev"
