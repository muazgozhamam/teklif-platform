#!/usr/bin/env bash
set -euo pipefail

# === MUST RUN FROM PROJECT ROOT ===
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "❌ HATA: Script proje kökünden çalıştırılmalıdır."
  echo "👉 cd ~/Desktop/teklif-platform"
  exit 1
fi

API_DIR="apps/api"
PORT="${PORT:-3001}"

echo "==> Port kontrol: $PORT"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "❌ Port $PORT dolu. Şunu çalıştır ve kapat:"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN
  exit 1
fi

echo "==> API dev başlatılıyor (PORT=$PORT)..."
cd "$API_DIR"

# .env yükle
set -a
source ./.env
set +a

export PORT="$PORT"

echo "==> Çıkış: Ctrl+C"
pnpm start:dev
