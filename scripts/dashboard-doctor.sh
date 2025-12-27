#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASH_DIR="$ROOT/apps/dashboard"
API_BASE="${API_BASE:-http://localhost:3001}"

echo "==> 1) API health kontrol"
if curl -fsS "$API_BASE/health" >/dev/null 2>&1; then
  echo "✅ API OK: $API_BASE/health"
else
  echo "❌ API kapalı: $API_BASE/health"
  echo "   API başlat:"
  echo "     cd $ROOT/apps/api && pnpm start:dev"
fi

echo
echo "==> 2) Dashboard port kontrolleri (3000/3002/3003)"
for PORT in 3000 3002 3003; do
  if curl -fsS "http://localhost:$PORT" >/dev/null 2>&1; then
    echo "✅ Dashboard cevap veriyor: http://localhost:$PORT"
  else
    echo " - http://localhost:$PORT yok"
  fi
done

echo
echo "==> 3) 3000 portunu kim dinliyor?"
lsof -nP -iTCP:3000 -sTCP:LISTEN || echo " - 3000 LISTEN yok"

echo
echo "==> 4) Dashboard 'pnpm dev' çalıştırma önerisi"
echo "Komut (ayrı terminalde):"
echo "  cd $DASH_DIR && pnpm dev"
echo
echo "Eğer 3000 doluysa, Next otomatik başka port seçecek."
echo "Terminal çıktısında 'Local: http://localhost:XXXX' satırına bak."
