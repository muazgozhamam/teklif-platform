#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN_TS="$ROOT/apps/api/src/main.ts"

if [ ! -f "$MAIN_TS" ]; then
  echo "HATA: main.ts bulunamadı: $MAIN_TS"
  exit 1
fi

echo "==> Fixing $MAIN_TS (remove bad top-level seed, dedupe imports, re-insert inside bootstrap)"

node <<'NODE'
const fs = require('fs');

const mainPath = process.env.MAIN_TS || (process.cwd() + '/apps/api/src/main.ts');
let src = fs.readFileSync(mainPath, 'utf8');

function ensureImport(src, what, from) {
  const re = new RegExp(`import\\s*\\{\\s*${what}\\s*\\}\\s*from\\s*['"]${from}['"]\\s*;`);
  if (re.test(src)) return src;

  const m = src.match(/^(import[\s\S]*?\n)(?!import)/m);
  const line = `import { ${what} } from '${from}';\n`;
  if (m) return src.slice(0, m[1].length) + line + src.slice(m[1].length);
  return line + src;
}

// 1) main.ts içinde DevSeedModule importları tamamen kaldır (kullanılmamalı)
src = src.replace(/^\s*import\s+\{\s*DevSeedModule\s*\}\s+from\s+['"][^'"]+['"];\s*\n/gm, '');

// 2) Yanlış yere eklenmiş (top-level) dev-seed bloklarını kaldır.
//    Heuristics: "DEV SEED (idempotent)" yorumundan başlayan if bloğunu temizle.
src = src.replace(
  /^\s*\/\/\s*DEV SEED[\s\S]*?\n\s*\}\s*\n\s*\}\s*\n/gm,
  ''
);

// 3) Eğer daha kısa varyant kaldıysa (yalnız if bloğu), onu da sil
src = src.replace(
  /^\s*if\s*\(\s*process\.env\.DEV_SEED\s*===?\s*['"]1['"]\s*\)\s*\{[\s\S]*?\n\s*\}\s*\n/gm,
  ''
);

// 4) DevSeedService importunu garanti et (tek ve doğru path ile)
//    Önce muhtemel yanlış path importlarını kaldır (varsa)
src = src.replace(/^\s*import\s+\{\s*DevSeedService\s*\}\s+from\s+['"][^'"]+['"];\s*\n/gm, '');
src = ensureImport(src, 'DevSeedService', './dev-seed/dev-seed.service');

// 5) Seed bloğunu bootstrap içinde, NestFactory ile app oluşturulduktan hemen sonra ekle (idempotent)
//    Zaten doğru blok varsa ekleme.
const hasGoodSeed = /process\.env\.DEV_SEED\s*===\s*['"]1['"][\s\S]*?get\(DevSeedService\)\.seed\(\)/m.test(src);
if (!hasGoodSeed) {
  // bootstrap fonksiyonunu bul
  const bootstrapRe = /async\s+function\s+bootstrap\s*\(\s*\)\s*\{[\s\S]*?\n\}/m;
  const bm = src.match(bootstrapRe);
  if (!bm) {
    console.error("HATA: bootstrap() fonksiyonu bulunamadı.");
    process.exit(1);
  }

  const block = bm[0];

  // app create assignment yakala (const/let <var> = await NestFactory....(AppModule...);)
  const createRe = /(const|let)\s+(\w+)\s*=\s*await\s+NestFactory\.\w+\s*(?:<[^>]*>)?\s*\(\s*AppModule\b[\s\S]*?\)\s*;\s*/m;
  const cm = block.match(createRe);
  if (!cm) {
    console.error("HATA: bootstrap içinde NestFactory.*(AppModule) satırı bulunamadı.");
    process.exit(1);
  }

  const appVar = cm[2];
  const insertAt = cm.index + cm[0].length;

  const seedBlock =
`\n  // DEV SEED (idempotent) — run only when DEV_SEED=1
  if (process.env.DEV_SEED === '1') {
    try {
      await ${appVar}.get(DevSeedService).seed();
      // eslint-disable-next-line no-console
      console.log('[dev-seed] seeded');
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn('[dev-seed] seed failed:', e?.message ?? e);
    }
  }\n`;

  const patchedBlock = block.slice(0, insertAt) + seedBlock + block.slice(insertAt);
  src = src.replace(block, patchedBlock);
}

// 6) Import duplications normalize: aynı import satırları tekrar etmiş olabilir.
//    Basit bir dedupe: import satırlarını set ile toparla (yalnız same-line exact match).
const lines = src.split('\n');
const seen = new Set();
const out = [];
for (const line of lines) {
  if (/^\s*import\s+/.test(line)) {
    if (seen.has(line)) continue;
    seen.add(line);
  }
  out.push(line);
}
src = out.join('\n');

fs.writeFileSync(mainPath, src, 'utf8');
console.log("OK: main.ts fixed");
NODE

echo "==> Rebuild API"
cd "$ROOT/apps/api"
pnpm -s build

echo
echo "DONE."
echo "Şimdi API'yi başlat:"
echo "  cd $ROOT/apps/api && DEV_SEED=1 pnpm start:dev"
echo "Test:"
echo "  curl -i http://localhost:3001/health"
