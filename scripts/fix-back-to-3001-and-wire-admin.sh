#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

# @teklif/admin app'i bul
ADMIN_APP=""
for d in "$ROOT"/apps/*; do
  if [ -f "$d/package.json" ]; then
    if node -e "const j=require('$d/package.json'); process.exit(j.name==='@teklif/admin'?0:1)"; then
      ADMIN_APP="$d"
      break
    fi
  fi
done

if [ -z "$ADMIN_APP" ]; then
  echo "HATA: @teklif/admin app bulunamadı."
  exit 1
fi
if [ ! -d "$API" ]; then
  echo "HATA: apps/api yok."
  exit 1
fi

echo "==> 1) Port temizliği (3000-3003,3011)"
for PORT in 3000 3001 3002 3003 3011; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> $PIDS kill -9"
    kill -9 $PIDS || true
  fi
done

echo "==> 2) Next lock/cache temizliği"
rm -f "$ROOT/apps/admin/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/admin/.next" 2>/dev/null || true
rm -rf "$ROOT/.turbo" 2>/dev/null || true

echo "==> 3) apps/api/.env -> PORT=3001"
ENV_API="$API/.env"
touch "$ENV_API"
if ! grep -q "^PORT=" "$ENV_API"; then
  printf "\nPORT=3001\n" >> "$ENV_API"
else
  perl -i -pe "s/^PORT=.*/PORT=3001/" "$ENV_API"
fi

echo "==> 4) Admin .env.local -> API_BASE_URL=http://localhost:3001"
ENV_ADMIN="$ADMIN_APP/.env.local"
touch "$ENV_ADMIN"
if ! grep -q "^API_BASE_URL=" "$ENV_ADMIN"; then
  printf "\nAPI_BASE_URL=http://localhost:3001\n" >> "$ENV_ADMIN"
else
  perl -i -pe "s#^API_BASE_URL=.*#API_BASE_URL=http://localhost:3001#" "$ENV_ADMIN"
fi

echo
echo "==> OK. Şimdi sadece API+ADMIN başlat:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
echo
echo "Kontrol: curl http://localhost:3001/health"
