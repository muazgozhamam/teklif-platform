#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

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

PROXY="$ADMIN_APP/src/lib/proxy.ts"
ENV_ADMIN="$ADMIN_APP/.env.local"

if [ ! -f "$PROXY" ]; then
  echo "HATA: proxy.ts yok: $PROXY"
  exit 1
fi

echo "==> 1) proxy.ts default API base -> 3001"
# getApiBase() default'u 3011 ise 3001 yap
perl -0777 -i -pe "s|('http://localhost:)(3011)(')|\\1 3001\\3|g; s|('http://localhost:)(3001)(')|\\1 3001\\3|g" "$PROXY"
# boşluk olursa düzelt
perl -i -pe "s/'http:\\/\\/localhost:\\s*3001'/'http:\\/\\/localhost:3001'/g" "$PROXY"

echo "==> 2) Admin .env.local -> API_BASE_URL=http://localhost:3001"
touch "$ENV_ADMIN"
if ! grep -q "^API_BASE_URL=" "$ENV_ADMIN"; then
  printf "\nAPI_BASE_URL=http://localhost:3001\n" >> "$ENV_ADMIN"
else
  perl -i -pe "s#^API_BASE_URL=.*#API_BASE_URL=http://localhost:3001#" "$ENV_ADMIN"
fi

echo "==> 3) Port temizliği (3001,3002)"
for PORT in 3001 3002; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> $PIDS kill -9"
    kill -9 $PIDS || true
  fi
done

echo "==> OK. Şimdi dev'i yeniden başlat:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
