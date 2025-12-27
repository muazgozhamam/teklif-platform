#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "==> 1) Port temizliği (3000,3001,3002,3003,3011)"
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
rm -f "$ROOT/apps/dashboard/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/dashboard/.next" 2>/dev/null || true
rm -rf "$ROOT/.turbo" 2>/dev/null || true

API="$ROOT/apps/api"
ADMIN_APP=""

# @teklif/admin app'i bul
for d in "$ROOT"/apps/*; do
  if [ -f "$d/package.json" ]; then
    if node -e "const j=require('$d/package.json'); process.exit(j.name==='@teklif/admin'?0:1)"; then
      ADMIN_APP="$d"
      break
    fi
  fi
done

if [ ! -d "$API" ]; then
  echo "HATA: apps/api yok"
  exit 1
fi
if [ -z "$ADMIN_APP" ]; then
  echo "HATA: @teklif/admin app bulunamadı"
  exit 1
fi

echo "==> 3) API main.ts PORT env ile dinlesin"
MAIN="$API/src/main.ts"
if [ ! -f "$MAIN" ]; then
  echo "HATA: $MAIN yok"
  exit 1
fi

node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/apps/api/src/main.ts';
let s = fs.readFileSync(p,'utf8');

// listen(...) satırını PORT env'e bağla (varsa dokunma)
if (!s.includes('process.env.PORT')) {
  // en basit: listen(3001) veya listen(PORT) yakalayıp değiştir
  s = s.replace(/await\s+app\.listen\(([^)]+)\)\s*;/, (m, portExpr) => {
    return `await app.listen(process.env.PORT ? Number(process.env.PORT) : ${portExpr});`;
  });
  fs.writeFileSync(p, s);
  console.log('OK: main.ts listen -> process.env.PORT destekli');
} else {
  console.log('OK: main.ts zaten process.env.PORT destekli');
}
NODE

echo "==> 4) apps/api/.env -> PORT=3011 + DEV_AUTH_BYPASS=1"
ENV_API="$API/.env"
touch "$ENV_API"
if ! grep -q "^PORT=" "$ENV_API"; then
  printf "\nPORT=3011\n" >> "$ENV_API"
else
  perl -i -pe "s/^PORT=.*/PORT=3011/" "$ENV_API"
fi

if ! grep -q "^DEV_AUTH_BYPASS=" "$ENV_API"; then
  printf "\nDEV_AUTH_BYPASS=1\n" >> "$ENV_API"
else
  perl -i -pe "s/^DEV_AUTH_BYPASS=.*/DEV_AUTH_BYPASS=1/" "$ENV_API"
fi

echo "==> 5) Admin app .env.local -> API_BASE_URL=http://localhost:3011"
ENV_ADMIN="$ADMIN_APP/.env.local"
touch "$ENV_ADMIN"
if ! grep -q "^API_BASE_URL=" "$ENV_ADMIN"; then
  printf "\nAPI_BASE_URL=http://localhost:3011\n" >> "$ENV_ADMIN"
else
  perl -i -pe "s#^API_BASE_URL=.*#API_BASE_URL=http://localhost:3011#" "$ENV_ADMIN"
fi

echo "==> OK: API 3011'e taşındı, Admin proxy 3011'e bağlandı."
echo
echo "Şimdi şu komutla kaldır:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
echo
echo "Kontrol:"
echo "curl -i http://localhost:3011/health"
