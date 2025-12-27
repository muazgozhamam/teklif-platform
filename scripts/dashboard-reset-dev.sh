#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DIR="$ROOT/apps/dashboard"

echo "==> 1) Dashboard portlarını temizle (3000/3002/3003) - API 3001'e dokunma"
kill_port() {
  local PORT="$1"
  local PIDS
  PIDS="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$PIDS" ]]; then
    echo " - Port $PORT LISTEN pid: $PIDS -> kill -9"
    kill -9 $PIDS 2>/dev/null || true
  else
    echo " - Port $PORT boş"
  fi
}

kill_port 3000
kill_port 3002
kill_port 3003

echo
echo "==> 2) Next dev lock temizliği"
LOCK="$DASH_DIR/.next/dev/lock"
if [[ -f "$LOCK" ]]; then
  echo " - Siliniyor: $LOCK"
  rm -f "$LOCK"
else
  echo " - Lock yok"
fi

echo
echo "==> 3) (Opsiyonel ama faydalı) Turbopack cache temizliği"
# sadece dev cache; prod build'i etkilemez
if [[ -d "$DASH_DIR/.next" ]]; then
  rm -rf "$DASH_DIR/.next/cache" 2>/dev/null || true
fi

echo
echo "==> 4) Dashboard'u başlat (3000 tercih edilir)"
cd "$DASH_DIR"
# Next 3000 boşsa 3000'de açılır
pnpm dev
