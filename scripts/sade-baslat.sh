#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

echo "==> Port temizliği (3001, 3002)"
for PORT in 3001 3002; do
  PIDS="$(lsof -ti tcp:$PORT || true)"
  if [ -n "$PIDS" ]; then
    echo "kill -9 $PIDS"
    kill -9 $PIDS || true
  fi
done

echo "==> Next lock temizliği"
rm -f "$ROOT/apps/admin/.next/dev/lock" 2>/dev/null || true
rm -rf "$ROOT/apps/admin/.next" 2>/dev/null || true

API_DIR="$ROOT/apps/api"
ADMIN_DIR=""

# @teklif/admin klasörünü bul
for d in "$ROOT"/apps/*; do
  if [ -f "$d/package.json" ]; then
    if node -e "const j=require('$d/package.json'); process.exit(j.name==='@teklif/admin'?0:1)"; then
      ADMIN_DIR="$d"
      break
    fi
  fi
done

[ -d "$API_DIR" ] || { echo "HATA: apps/api yok"; exit 1; }
[ -n "$ADMIN_DIR" ] || { echo "HATA: apps/@teklif/admin bulunamadı"; exit 1; }

echo "==> API: health endpoint garanti"
APP_CONTROLLER="$API_DIR/src/app.controller.ts"
APP_SERVICE="$API_DIR/src/app.service.ts"
APP_MODULE="$API_DIR/src/app.module.ts"

if [ ! -f "$APP_SERVICE" ]; then
cat > "$APP_SERVICE" <<'TS'
import { Injectable } from '@nestjs/common';
@Injectable()
export class AppService {
  health() { return { ok: true }; }
}
TS
fi

if [ ! -f "$APP_CONTROLLER" ]; then
cat > "$APP_CONTROLLER" <<'TS'
import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}
  @Get('health') health() { return this.appService.health(); }
}
TS
fi

# app.module.ts içinde AppController/AppService yoksa ekle
node <<'NODE'
const fs=require('fs');
const p='apps/api/src/app.module.ts';
let s=fs.readFileSync(p,'utf8');
if(!s.includes("AppController")) s = "import { AppController } from './app.controller';\n" + s;
if(!s.includes("AppService")) s = "import { AppService } from './app.service';\n" + s;

s = s.replace(/controllers:\s*\[/, 'controllers: [AppController, ');
s = s.replace(/providers:\s*\[/, 'providers: [AppService, ');

fs.writeFileSync(p,s);
console.log('OK: app.module.ts updated');
NODE

echo "==> API: AdminController DEV için auth'suz (guards kaldır)"
ADMIN_CTRL="$API_DIR/src/admin/admin.controller.ts"
if [ -f "$ADMIN_CTRL" ]; then
  cp "$ADMIN_CTRL" "$ADMIN_CTRL.bak.$(date +%s)"
  # @UseGuards ve @Roles satırlarını kaldır
  perl -i -pe "s/^.*@UseGuards\\(.*\\)\\s*\$\\n//m; s/^.*@Roles\\(.*\\)\\s*\$\\n//m" "$ADMIN_CTRL"
fi

echo "==> Admin: API passthrough route'ları (proxy karmaşası yok)"
APP_ROUTER="$ADMIN_DIR/src/app"
if [ ! -d "$APP_ROUTER" ]; then APP_ROUTER="$ADMIN_DIR/app"; fi
[ -d "$APP_ROUTER" ] || { echo "HATA: admin app router yok (src/app veya app)"; exit 1; }

mkdir -p "$APP_ROUTER/api/admin/users" "$APP_ROUTER/api/admin/users/[id]/role"

cat > "$APP_ROUTER/api/admin/users/route.ts" <<'TS'
export const dynamic = 'force-dynamic';

const API_BASE = process.env.API_BASE_URL || 'http://localhost:3001';

export async function GET() {
  const r = await fetch(`${API_BASE}/admin/users`, { cache: 'no-store' });
  const t = await r.text();
  return new Response(t, { status: r.status, headers: { 'Content-Type': r.headers.get('content-type') || 'application/json' }});
}
TS

cat > "$APP_ROUTER/api/admin/users/[id]/role/route.ts" <<'TS'
export const dynamic = 'force-dynamic';

const API_BASE = process.env.API_BASE_URL || 'http://localhost:3001';

export async function PATCH(req: Request, ctx: { params: { id: string } }) {
  const body = await req.text();
  const r = await fetch(`${API_BASE}/admin/users/${ctx.params.id}/role`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body,
    cache: 'no-store',
  });
  const t = await r.text();
  return new Response(t, { status: r.status, headers: { 'Content-Type': r.headers.get('content-type') || 'application/json' }});
}
TS

echo "==> Start: API (3001) + Admin (3002) (logs: /tmp/teklif-*.log)"

API_SCRIPT="$(node -e "
const p=require(process.cwd()+'/apps/api/package.json'); const s=p.scripts||{};
if(s.dev) console.log('dev');
else if(s['start:dev']) console.log('start:dev');
else if(s['dev:watch']) console.log('dev:watch');
")"

ADMIN_SCRIPT="$(node -e "
const fs=require('fs');
const dir=process.argv[1];
const p=require(dir+'/package.json'); const s=p.scripts||{};
if(s.dev) console.log('dev'); else if(s['start:dev']) console.log('start:dev'); else console.log('dev');
" "$ADMIN_DIR")"

nohup bash -lc "cd '$API_DIR' && PORT=3001 NODE_ENV=development pnpm run '$API_SCRIPT'" > /tmp/teklif-api.log 2>&1 &
nohup bash -lc "cd '$ADMIN_DIR' && API_BASE_URL=http://localhost:3001 PORT=3002 pnpm run '$ADMIN_SCRIPT'" > /tmp/teklif-admin.log 2>&1 &

echo "==> Bekleniyor: API /health"
for i in {1..40}; do
  if curl -fsS http://localhost:3001/health >/dev/null 2>&1; then
    echo "OK: API up"
    break
  fi
  sleep 0.5
done

if ! curl -fsS http://localhost:3001/health >/dev/null 2>&1; then
  echo "HATA: API kalkmadı. Son 80 satır:"
  tail -n 80 /tmp/teklif-api.log || true
  exit 1
fi

echo "==> READY"
echo "API:   http://localhost:3001/health"
echo "Admin: http://localhost:3002/admin/users"
