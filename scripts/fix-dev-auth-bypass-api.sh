#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

JWT_GUARD="$API/src/auth/jwt-auth.guard.ts"
ROLES_GUARD="$API/src/common/roles.guard.ts"

if [ ! -f "$JWT_GUARD" ]; then
  echo "HATA: jwt-auth.guard.ts bulunamadı: $JWT_GUARD"
  exit 1
fi
if [ ! -f "$ROLES_GUARD" ]; then
  echo "HATA: roles.guard.ts bulunamadı: $ROLES_GUARD"
  exit 1
fi

echo "==> Patch: JwtAuthGuard -> DEV_AUTH_BYPASS desteği"
# canActivate başına bypass ekle
node <<NODE
const fs=require('fs');
const p="${JWT_GUARD}";
let s=fs.readFileSync(p,'utf8');

if (!s.includes('DEV_AUTH_BYPASS')) {
  // canActivate içine bypass enjekte et
  s = s.replace(/async\\s+canActivate\\(([^)]*)\\)\\s*\\{/, (m,args) => {
    return \`async canActivate(\${args}) {\n    if (process.env.DEV_AUTH_BYPASS === '1') return true;\`;
  });
  fs.writeFileSync(p,s);
  console.log('OK: JwtAuthGuard patched');
} else {
  console.log('OK: JwtAuthGuard already patched');
}
NODE

echo "==> Patch: RolesGuard -> DEV_AUTH_BYPASS desteği"
node <<NODE
const fs=require('fs');
const p="${ROLES_GUARD}";
let s=fs.readFileSync(p,'utf8');

if (!s.includes('DEV_AUTH_BYPASS')) {
  // canActivate içine bypass enjekte et
  s = s.replace(/canActivate\\(([^)]*)\\)\\s*\\{/, (m,args) => {
    return \`canActivate(\${args}) {\n    if (process.env.DEV_AUTH_BYPASS === '1') return true;\`;
  });
  fs.writeFileSync(p,s);
  console.log('OK: RolesGuard patched');
} else {
  console.log('OK: RolesGuard already patched');
}
NODE

echo "==> apps/api/.env dosyasına DEV_AUTH_BYPASS=1 ekleniyor"
ENVFILE="$API/.env"
if [ ! -f "$ENVFILE" ]; then
  echo "DEV_AUTH_BYPASS=1" > "$ENVFILE"
else
  if ! grep -q "^DEV_AUTH_BYPASS=" "$ENVFILE"; then
    printf "\nDEV_AUTH_BYPASS=1\n" >> "$ENVFILE"
  else
    # var ama farklıysa 1 yap
    perl -i -pe "s/^DEV_AUTH_BYPASS=.*/DEV_AUTH_BYPASS=1/" "$ENVFILE"
  fi
fi

echo "==> OK: Dev bypass aktif. API'yi yeniden başlatınca admin endpointler 401 vermez."
echo "Dev çalışıyorsa turbo'yu restart et (Ctrl+C -> pnpm dev)."
