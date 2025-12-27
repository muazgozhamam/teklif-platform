#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

JWT_GUARD="$API/src/auth/jwt-auth.guard.ts"
ROLES_GUARD="$API/src/common/roles.guard.ts"

if [ ! -f "$JWT_GUARD" ]; then
  echo "HATA: $JWT_GUARD yok"
  exit 1
fi
if [ ! -f "$ROLES_GUARD" ]; then
  echo "HATA: $ROLES_GUARD yok"
  exit 1
fi

echo "==> JwtAuthGuard: dev default bypass (DEV_AUTH_BYPASS!=0)"
node <<'NODE'
const fs=require('fs');
const p=process.cwd()+"/apps/api/src/auth/jwt-auth.guard.ts";
let s=fs.readFileSync(p,'utf8');

// Daha önce eklenen bypass satırlarını normalize edeceğiz
// canActivate bloğunun en başına tek satır ekleyeceğiz.
const bypassLine = "    if (process.env.NODE_ENV !== 'production' && process.env.DEV_AUTH_BYPASS !== '0') return true;";

if (!s.includes(bypassLine)) {
  // Eski DEV_AUTH_BYPASS check varsa silme zahmetine girmeden, canActivate başına ekle.
  s = s.replace(/(async\s+canActivate\([^\)]*\)\s*\{\s*)/m, (m, g1) => g1 + "\n" + bypassLine + "\n");
  fs.writeFileSync(p,s);
  console.log("OK: JwtAuthGuard patched");
} else {
  console.log("OK: JwtAuthGuard already ok");
}
NODE

echo "==> RolesGuard: dev default bypass (DEV_AUTH_BYPASS!=0)"
node <<'NODE'
const fs=require('fs');
const p=process.cwd()+"/apps/api/src/common/roles.guard.ts";
let s=fs.readFileSync(p,'utf8');
const bypassLine = "    if (process.env.NODE_ENV !== 'production' && process.env.DEV_AUTH_BYPASS !== '0') return true;";

if (!s.includes(bypassLine)) {
  s = s.replace(/(canActivate\([^\)]*\)\s*\{\s*)/m, (m, g1) => g1 + "\n" + bypassLine + "\n");
  fs.writeFileSync(p,s);
  console.log("OK: RolesGuard patched");
} else {
  console.log("OK: RolesGuard already ok");
}
NODE

echo "==> OK. Dev’de bypass default ON. Kapatmak istersen DEV_AUTH_BYPASS=0 verirsin."
echo "Şimdi dev’i restart et:"
echo "  Ctrl+C"
echo "  pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
