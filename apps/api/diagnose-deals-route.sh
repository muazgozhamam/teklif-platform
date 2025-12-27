#!/usr/bin/env bash
set -euo pipefail

echo "==> 0) PWD"
pwd

echo
echo "==> 1) 3001 portunu kim dinliyor?"
(lsof -nP -iTCP:3001 -sTCP:LISTEN || true)

echo
echo "==> 2) apps/api main.ts hangi module boot ediyor?"
API_MAIN="src/main.ts"
if [ -f "$API_MAIN" ]; then
  echo "--- src/main.ts (ilk 200 satır) ---"
  sed -n '1,200p' "$API_MAIN"
  echo "----------------------------------"
else
  echo "UYARI: src/main.ts bulunamadı."
fi

echo
echo "==> 3) Route dump (Nest init edip route listeler) — terminal BLOKLAMAZ"
# scripts/route-dump.ts var mı, yoksa hızlıca oluştur
mkdir -p scripts
cat > scripts/route-dump.ts <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';

async function main() {
  const app = await NestFactory.create(AppModule, { logger: false });
  await app.init();

  const server: any = app.getHttpServer();
  const router = server?._events?.request?._router;

  const routes: string[] = [];
  if (router?.stack) {
    for (const layer of router.stack) {
      if (layer?.route?.path) {
        const methods = Object.keys(layer.route.methods || {}).filter((m) => layer.route.methods[m]);
        routes.push(`${methods.join(',').toUpperCase()} ${layer.route.path}`);
      }
    }
  }

  routes.sort();
  for (const r of routes) console.log(r);

  await app.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
TS

# ts-node yoksa pnpm dlx ile çalıştırmayı dene
if pnpm -s ts-node -v >/dev/null 2>&1; then
  pnpm -s ts-node scripts/route-dump.ts | grep -i deals || true
else
  pnpm -s dlx ts-node scripts/route-dump.ts | grep -i deals || true
fi

echo
echo "==> 4) Kod tarafında Deals controller dosyaları var mı?"
ls -la src/deals || true
[ -f "src/deals/deals.controller.ts" ] && echo "OK: deals.controller.ts var" || echo "HATA: deals.controller.ts yok"
[ -f "src/deals/deals.module.ts" ] && echo "OK: deals.module.ts var" || echo "HATA: deals.module.ts yok"
[ -f "src/deals/deals.service.ts" ] && echo "OK: deals.service.ts var" || echo "HATA: deals.service.ts yok"

echo
echo "==> DONE (diagnose)"
echo "NOT: Eğer pnpm start:dev çalışıyorsa o terminal BLOKLUDUR; route değişiklikleri için restart gerekir."
