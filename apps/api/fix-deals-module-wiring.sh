#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/app.module.ts" ] || { echo "HATA: src/app.module.ts bulunamadı."; exit 1; }
[ -f "src/deals/deals.module.ts" ] || { echo "HATA: src/deals/deals.module.ts yok. Deal scripti tam oluşmamış."; exit 1; }
[ -f "src/deals/deals.controller.ts" ] || { echo "HATA: src/deals/deals.controller.ts yok. Route dosyası oluşmamış."; exit 1; }

echo "==> 1) src/app.module.ts içine DealsModule import + @Module imports'a ekleme (robust patch)"

node - <<'NODE'
const fs = require("fs");
const p = "src/app.module.ts";
let t = fs.readFileSync(p, "utf8");

// 1) Import satırı yoksa ekle
const importLine = `import { DealsModule } from './deals/deals.module';`;
if (!t.includes(importLine)) {
  // son import'un altına ekle
  const importMatches = [...t.matchAll(/^import .*;$/gm)];
  if (importMatches.length) {
    const last = importMatches[importMatches.length - 1];
    const idx = last.index + last[0].length;
    t = t.slice(0, idx) + "\n" + importLine + t.slice(idx);
  } else {
    t = importLine + "\n" + t;
  }
}

// 2) @Module decorator object içinde imports alanını düzenle
const moduleMatch = t.match(/@Module\s*\(\s*\{[\s\S]*?\}\s*\)\s*\nexport\s+class\s+AppModule/m);
if (!moduleMatch) {
  console.error("HATA: app.module.ts içinde @Module({...}) export class AppModule bloğu bulunamadı. Yapı farklı.");
  process.exit(1);
}

const block = moduleMatch[0];

// imports: [...] var mı?
if (block.includes("imports:")) {
  // imports array'i yakala
  const patched = block.replace(/imports\s*:\s*\[([\s\S]*?)\]/m, (m, inner) => {
    if (inner.includes("DealsModule")) return m;

    // Boşsa direkt ekle
    if (!inner.trim()) return "imports: [DealsModule]";

    // Sonuna ekle (virgül durumuna dikkat)
    const innerTrimRight = inner.replace(/\s+$/,"");
    const needsComma = !innerTrimRight.trim().endsWith(",");
    return `imports: [${innerTrimRight}${needsComma ? "," : ""} DealsModule]`;
  });
  t = t.replace(block, patched);
} else {
  // imports alanı yoksa @Module objesinin en başına ekle
  const patched = block.replace(/@Module\s*\(\s*\{/m, "@Module({\n  imports: [DealsModule],");
  t = t.replace(block, patched);
}

fs.writeFileSync(p, t, "utf8");
console.log("==> app.module.ts patched (DealsModule wired).");
NODE

echo "==> 2) Route dump scripti ekleniyor (debug için)"
cat > scripts/route-dump.ts <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';

async function main() {
  const app = await NestFactory.create(AppModule, { logger: false });
  await app.init();

  // Express router stack
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

echo "==> 3) TypeScript build doğrulama"
pnpm -s build

echo "==> DONE"
echo
echo "Şimdi DEV server'ı restart etmen gerekiyor."
echo "NOT: pnpm start:dev terminali BLOKLAR (açık kalır)."
echo
echo "Restart:"
echo "  Ctrl+C (çalışıyorsa) ve sonra:"
echo "  pnpm start:dev"
echo
echo "Route doğrulama (ayrı terminalde, bu komut terminali BLOKLAMAZ):"
echo "  pnpm -s ts-node scripts/route-dump.ts | grep -i deals || true"
