#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"
APP_MODULE="$API/src/app.module.ts"

if [ ! -f "$APP_MODULE" ]; then
  echo "HATA: apps/api/src/app.module.ts bulunamadı: $APP_MODULE"
  exit 1
fi

echo "==> Backup alınıyor"
cp "$APP_MODULE" "$APP_MODULE.bak.$(date +%s)"

echo "==> ConfigModule.forRoot envFilePath patch"

node <<'NODE'
const fs = require('fs');
const path = require('path');

const p = path.join(process.cwd(), 'apps/api/src/app.module.ts');
let s = fs.readFileSync(p, 'utf8');

// 1) path import yoksa ekle
if (!s.includes("from 'path'") && !s.includes('from "path"')) {
  // En üstteki import bloklarına eklemeye çalış
  s = s.replace(/(^import[\s\S]*?\n)(\n|@Module)/m, (m, imports, sep) => {
    if (imports.includes("from 'path'") || imports.includes('from "path"')) return m;
    return imports + "import * as path from 'path';\n" + sep;
  });
}

// 2) ConfigModule.forRoot(...) yakala ve içine envFilePath ekle
// Eğer zaten envFilePath varsa dokunma
if (s.includes('ConfigModule.forRoot') && !s.includes('envFilePath')) {
  s = s.replace(/ConfigModule\.forRoot\(\s*\{([\s\S]*?)\}\s*\)/m, (m, inner) => {
    const envLines = `
    envFilePath: [
      path.resolve(process.cwd(), 'apps/api/.env'),
      path.resolve(process.cwd(), 'apps/api/.env.local'),
    ],`;
    // inner başına ekle
    return `ConfigModule.forRoot({${envLines}\n${inner}\n})`;
  });

  // Bazı projelerde ConfigModule.forRoot() boş parantezle olabilir
  s = s.replace(/ConfigModule\.forRoot\(\s*\)/m, () => {
    const envLines = `
ConfigModule.forRoot({
  envFilePath: [
    path.resolve(process.cwd(), 'apps/api/.env'),
    path.resolve(process.cwd(), 'apps/api/.env.local'),
  ],
})`;
    return envLines.trim();
  });
}

fs.writeFileSync(p, s);
console.log('OK: app.module.ts envFilePath patched (apps/api/.env sabitlendi).');
NODE

echo "==> apps/api/.env garanti: PORT=3011 ve DEV_AUTH_BYPASS=1"
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

echo "==> Port temizliği (3011, 3002)"
for PORT in 3011 3002; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "Port $PORT -> $PIDS kill -9"
    kill -9 $PIDS || true
  fi
done

echo
echo "==> Şimdi sadece API+ADMIN başlat:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
echo
echo "Kontrol (opsiyonel ama hızlı): curl -i http://localhost:3011/health"
