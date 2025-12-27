#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$ROOT/apps/api/src/main.ts"

if [ ! -f "$MAIN" ]; then
  echo "HATA: main.ts yok: $MAIN"
  exit 1
fi

echo "==> HARD FIX main.ts: $MAIN"

node <<'NODE'
const fs = require('fs');

const mainPath = process.env.MAIN || (process.cwd() + '/apps/api/src/main.ts');
let s = fs.readFileSync(mainPath, 'utf8');

// 0) DevSeedModule importlarını koşulsuz kaldır (duplicate problemi burada)
s = s.replace(/^\s*import\s+\{\s*DevSeedModule\s*\}\s+from\s+['"][^'"]+['"];\s*\n/gm, '');

// 1) Top-level DEV_SEED bloğunu (ve app.get seed satırını) temizle
//    - "DEV SEED" yorumlu bloklar
s = s.replace(/^\s*\/\/\s*DEV\s*SEED[\s\S]*?\n(?=\s*(?:async\s+function\s+bootstrap|\(async|\bconst\b|\bimport\b|$))/gm, '');
//    - bootstrap dışında kalan "await app.get(DevSeedService).seed();" satırı
//      (tek başına veya çevresindeki if bloğu ile)
s = s.replace(/^\s*await\s+app\.get\(DevSeedService\)\.seed\(\);\s*\n/gm, '');
s = s.replace(/^\s*if\s*\(\s*process\.env\.DEV_SEED\s*===?\s*['"]1['"]\s*\)\s*\{\s*\n[\s\S]*?\n\s*\}\s*\n/gm, '');

// 2) DevSeedService importunu normalize et: varsa yanlışlarını kaldır, doğruyu ekle
s = s.replace(/^\s*import\s+\{\s*DevSeedService\s*\}\s+from\s+['"][^'"]+['"];\s*\n/gm, '');

function insertImport(line) {
  // import bloklarının sonuna ekle
  const m = s.match(/^(import[\s\S]*?\n)(?!import)/m);
  if (m) s = s.slice(0, m[1].length) + line + s.slice(m[1].length);
  else s = line + s;
}

const correctImport = `import { DevSeedService } from './dev-seed/dev-seed.service';\n`;
if (!s.includes(correctImport.trim())) insertImport(correctImport);

// 3) Seed bloğunu bootstrap içine ekle (idempotent)
const hasSeedInside = /DEV SEED \(idempotent\)[\s\S]*?get\(DevSeedService\)\.seed\(\)/m.test(s);
if (!hasSeedInside) {
  // bootstrap bloğunu bul
  const bootRe = /async\s+function\s+bootstrap\s*\(\s*\)\s*\{[\s\S]*?\n\}\s*\n/m;
  const bm = s.match(bootRe);
  if (!bm) {
    console.error("HATA: async function bootstrap() bulunamadı.");
    process.exit(1);
  }

  const block = bm[0];

  // app create satırını bul (const/let app = await NestFactory... (AppModule...);)
  const createRe = /(const|let)\s+(\w+)\s*=\s*await\s+NestFactory\.\w+\s*(?:<[^>]*>)?\s*\(\s*AppModule\b[\s\S]*?\)\s*;\s*/m;
  const cm = block.match(createRe);
  if (!cm) {
    console.error("HATA: bootstrap içinde NestFactory.*(AppModule) bulunamadı.");
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

  const patched = block.slice(0, insertAt) + seedBlock + block.slice(insertAt);
  s = s.replace(block, patched);
}

// 4) Import satırlarını exact match ile dedupe et
const lines = s.split('\n');
const seen = new Set();
const out = [];
for (const line of lines) {
  if (/^\s*import\s+/.test(line)) {
    if (seen.has(line)) continue;
    seen.add(line);
  }
  out.push(line);
}
s = out.join('\n');

fs.writeFileSync(mainPath, s, 'utf8');
console.log("OK: hard-fixed main.ts");
NODE

echo "==> Build only API to verify"
cd "$ROOT/apps/api"
pnpm -s build

echo
echo "DONE. Şimdi root build deneyebilirsin:"
echo "  cd $ROOT && pnpm -s build"
