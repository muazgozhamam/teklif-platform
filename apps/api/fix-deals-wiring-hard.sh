#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/app.module.ts" ] || { echo "HATA: src/app.module.ts yok."; exit 1; }
[ -f "src/deals/deals.module.ts" ] || { echo "HATA: src/deals/deals.module.ts yok."; exit 1; }

echo "==> 1) Mevcut app.module.ts içinde DealsModule var mı? (gösterim)"
grep -n "DealsModule" -n src/app.module.ts || true
echo "---- app.module.ts (Module decorator çevresi) ----"
# @Module bloğunun çevresini gösterelim
awk 'NR>=1 && NR<=220 {print}' src/app.module.ts | sed -n '1,220p'
echo "-------------------------------------------------"

echo
echo "==> 2) app.module.ts: DealsModule import + imports[] içine kesin ekle (agresif ama güvenli)"
node - <<'NODE'
const fs = require("fs");
const p = "src/app.module.ts";
let t = fs.readFileSync(p, "utf8");

const importStmt = `import { DealsModule } from './deals/deals.module';`;

// Import ekle (yoksa)
if (!t.includes(importStmt)) {
  const importLines = [...t.matchAll(/^import .*;$/gm)];
  if (importLines.length) {
    const last = importLines[importLines.length - 1];
    const idx = last.index + last[0].length;
    t = t.slice(0, idx) + "\n" + importStmt + t.slice(idx);
  } else {
    t = importStmt + "\n" + t;
  }
}

// @Module({...}) objesini bul
const modObjMatch = t.match(/@Module\s*\(\s*\{[\s\S]*?\}\s*\)\s*\nexport\s+class\s+AppModule/m);
if (!modObjMatch) {
  console.error("HATA: @Module({...}) export class AppModule bloğu bulunamadı.");
  process.exit(1);
}

let block = modObjMatch[0];

// imports alanı yoksa ekle
if (!/imports\s*:\s*\[/.test(block)) {
  block = block.replace(/@Module\s*\(\s*\{\s*/m, (m) => `${m}\n  imports: [DealsModule],\n`);
} else {
  // imports array'ine DealsModule ekle (yoksa)
  block = block.replace(/imports\s*:\s*\[([\s\S]*?)\]/m, (m, inner) => {
    if (inner.includes("DealsModule")) return m;

    const innerTrimRight = inner.replace(/\s+$/,"");
    const needsComma = innerTrimRight.trim() !== "" && !innerTrimRight.trim().endsWith(",");
    const glue = innerTrimRight.trim() === "" ? "DealsModule" : `${innerTrimRight}${needsComma ? "," : ""} DealsModule`;
    return `imports: [${glue}]`;
  });
}

// geri yaz
t = t.replace(modObjMatch[0], block);
fs.writeFileSync(p, t, "utf8");
console.log("==> app.module.ts forced-wired DealsModule.");
NODE

echo
echo "==> 3) Route dump scripti yaz (tam liste) + çalıştır (terminal BLOKLAMAZ)"
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

# Route listesi (tam)
if pnpm -s ts-node -v >/dev/null 2>&1; then
  pnpm -s ts-node scripts/route-dump.ts
else
  pnpm -s dlx ts-node scripts/route-dump.ts
fi

echo
echo "==> 4) Build"
pnpm -s build

echo
echo "==> DONE"
echo "Şimdi DEV server restart şart."
echo "NOT: pnpm start:dev terminali BLOKLAR (açık kalır). Kapatmak için Ctrl+C."
