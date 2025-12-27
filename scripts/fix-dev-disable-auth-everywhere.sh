#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

JWT_GUARD="$API/src/auth/jwt-auth.guard.ts"
ROLES_GUARD="$API/src/common/roles.guard.ts"
MAIN="$API/src/main.ts"

[ -f "$MAIN" ] || { echo "HATA: $MAIN yok"; exit 1; }

mkdir -p "$API/src/auth" "$API/src/common"

echo "==> 1) JwtAuthGuard overwrite (DEV: always allow)"
if [ -f "$JWT_GUARD" ]; then cp "$JWT_GUARD" "$JWT_GUARD.bak.$(date +%s)"; fi
cat > "$JWT_GUARD" <<'TS'
import { ExecutionContext, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(_context: ExecutionContext) {
    // DEV: auth kapalı
    if (process.env.NODE_ENV !== 'production') return true;
    return super.canActivate(_context) as any;
  }
}
TS

echo "==> 2) RolesGuard overwrite (DEV: always allow)"
if [ -f "$ROLES_GUARD" ]; then cp "$ROLES_GUARD" "$ROLES_GUARD.bak.$(date +%s)"; fi
cat > "$ROLES_GUARD" <<'TS'
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(_context: ExecutionContext): boolean {
    // DEV: role kontrolü kapalı
    if (process.env.NODE_ENV !== 'production') return true;
    const requiredRoles = this.reflector.getAllAndOverride<string[]>('roles', [
      _context.getHandler(),
      _context.getClass(),
    ]);
    if (!requiredRoles || requiredRoles.length === 0) return true;
    const req = _context.switchToHttp().getRequest();
    const role = req.user?.role;
    return !!role && requiredRoles.includes(role);
  }
}
TS

echo "==> 3) main.ts: DEV'de fake ADMIN user enjekte et"
cp "$MAIN" "$MAIN.bak.$(date +%s)"

node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/apps/api/src/main.ts';
let s = fs.readFileSync(p,'utf8');

// bootstrap içinde app yaratıldıktan sonra dev middleware ekle
// Zaten ekliyse tekrar ekleme
if (!s.includes('DEV_FAKE_ADMIN_USER')) {
  s = s.replace(
    /(const\s+app\s*=\s*await\s+NestFactory\.create\([^\)]*\);\s*)/m,
    `$1\n  // DEV_FAKE_ADMIN_USER: auth/roles kapalıyken request'e ADMIN user bas\n  if (process.env.NODE_ENV !== 'production') {\n    app.use((req: any, _res: any, next: any) => {\n      if (!req.user) req.user = { id: 'dev-admin', email: 'dev@local', role: 'ADMIN' };\n      next();\n    });\n  }\n`
  );
}

fs.writeFileSync(p,s);
console.log('OK: main.ts patched');
NODE

echo "==> 4) Port temizliği (3001,3002)"
for PORT in 3001 3002; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "kill -9 $PIDS"
    kill -9 $PIDS || true
  fi
done

echo "==> OK. Şimdi yeniden başlat:"
echo "pnpm -w turbo dev --filter=@teklif/api --filter=@teklif/admin"
