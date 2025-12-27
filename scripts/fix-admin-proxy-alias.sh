#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

# apps altında name'i @teklif/admin olan paketi bul
APP_DIR=""
for d in "$ROOT"/apps/*; do
  if [ -f "$d/package.json" ]; then
    if node -e "const j=require('$d/package.json'); process.exit(j.name==='@teklif/admin'?0:1)"; then
      APP_DIR="$d"
      break
    fi
  fi
done

if [ -z "$APP_DIR" ]; then
  echo "HATA: @teklif/admin app bulunamadı."
  exit 1
fi

# App Router dizini
APP_ROUTER="$APP_DIR/src/app"
if [ ! -d "$APP_ROUTER" ]; then APP_ROUTER="$APP_DIR/app"; fi
if [ ! -d "$APP_ROUTER" ]; then
  echo "HATA: App Router dizini yok (src/app veya app): $APP_DIR"
  exit 1
fi

R1="$APP_ROUTER/api/admin/users/route.ts"
R2="$APP_ROUTER/api/admin/users/[id]/role/route.ts"
PXY="$APP_DIR/src/lib/proxy.ts"

if [ ! -f "$PXY" ]; then
  echo "HATA: proxy.ts yok: $PXY"
  exit 1
fi
if [ ! -f "$R1" ]; then
  echo "HATA: route yok: $R1"
  exit 1
fi
if [ ! -f "$R2" ]; then
  echo "HATA: route yok: $R2"
  exit 1
fi

echo "==> Patch: $R1"
# src/app/api/admin/users/route.ts -> src/lib/proxy.ts : ../../../../lib/proxy
perl -0777 -i -pe "s|from\\s+['\\\"]@/lib/proxy['\\\"]|from '../../../../lib/proxy'|g" "$R1"

echo "==> Patch: $R2"
# src/app/api/admin/users/[id]/role/route.ts -> src/lib/proxy.ts : ../../../../../../lib/proxy
perl -0777 -i -pe "s|from\\s+['\\\"]@/lib/proxy['\\\"]|from '../../../../../../lib/proxy'|g" "$R2"

echo "==> OK: alias kaldırıldı (relative import). Next otomatik recompile edecek."
