#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/app.module.ts" ] || { echo "HATA: src/app.module.ts yok."; exit 1; }

echo "==> 1) scripts/ klasörü oluşturuluyor"
mkdir -p scripts

echo "==> 2) Route dump scripti yazılıyor (terminal BLOKLAMAZ)"
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

echo "==> 3) Build doğrulama"
pnpm -s build

echo
echo "==> DONE"
echo "Şimdi iki adım var:"
echo "  A) Route kontrol (BU komut terminali BLOKLAMAZ):"
echo "     pnpm -s ts-node scripts/route-dump.ts | grep -i deals || true"
echo
echo "  B) DEV server restart:"
echo "     (Çalışıyorsa Ctrl+C) sonra:"
echo "     pnpm start:dev"
echo
echo "NOT: pnpm start:dev terminali BLOKLAR (açık kalır)."
