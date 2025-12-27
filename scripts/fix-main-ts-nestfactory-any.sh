#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$ROOT/apps/api/src/main.ts"

if [ ! -f "$MAIN" ]; then
  echo "HATA: main.ts yok: $MAIN"
  exit 1
fi

echo "==> PATCH main.ts (NestFactory-any): $MAIN"

MAIN="$MAIN" node <<'NODE'
const fs = require('fs');

const mainPath = process.env.MAIN;
let s = fs.readFileSync(mainPath, 'utf8');

// 1) DevSeedModule importlarını kaldır (duplicate vs.)
s = s.replace(/^\s*import\s+\{\s*DevSeedModule\s*\}\s+from\s+['"][^'"]+['"];\s*\n/gm, '');

// 2) Top-level ya da bozuk seed parçalarını temizle
s = s.replace(/^\s*await\s+app\.get\(DevSeedService\)\.seed\(\);\s*\n/gm, '');
s = s.replace(/^\s*if\s*\(\s*process\.env\.DEV_SEED\s*===?\s*['"]1['"]\s*\)\s*\{\s*\n[\s\S]*?\n\s*\}\s*\n/gm, '');

// 3) DevSeedService importlarını normalize et (tüm varyasyonları sil)
s = s.replace(/^\s*import\s+\{\s*DevSeedService\s*\}\s+from\s+['"][^'"]+['"];\s*\n/gm, '');

// 4) Doğru importu ekle (import bloklarının sonuna)
const correctImportLine = `import { DevSeedService } from './dev-seed/dev-seed.service';\n`;
if (!s.includes(correctImportLine.trim())) {
  const importBlockMatch = s.match(/^(?:\s*import[\s\S]*?\n)+/m);
  if (importBlockMatch) {
    const idx = importBlockMatch[0].length;
    s = s.slice(0, idx) + correctImportLine + s.slice(idx);
  } else {
    s = correctImportLine + s;
  }
}

// 5) Seed bloğu zaten var mı? (idempotent)
const seedMarker = 'DEV SEED (idempotent)';
if (!s.includes(seedMarker)) {
  // "const app = await NestFactory.create..." veya "let app = await NestFactory..."
  // ya da "const app = await NestFactory.createMicroservice..." vb.
  // Burada hedef: ilk NestFactory.* await satırını yakalayıp hemen altına eklemek.
  const re = /(^[ \t]*(?:const|let)\s+([A-Za-z_$][\w$]*)\s*=\s*await\s+NestFactory\.[A-Za-z_$][\w$]*\s*(?:<[^>]*>)?\s*\([\s\S]*?\)\s*;\s*$)/m;
  const m = s.match(re);

  if (!m) {
    console.error("HATA: Dosyada '(const|let) <var> = await NestFactory.<...>(...)' satırı bulunamadı.");
    process.exit(1);
  }

  const fullLine = m[1];
  const appVar = m[2];

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

  // Full line’ın hemen altına ekle
  s = s.replace(fullLine, fullLine + seedBlock);
}

// 6) Import satırlarını birebir dedupe et
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
console.log("OK: patched main.ts with NestFactory-any strategy");
NODE

echo "==> Build only API to verify"
cd "$ROOT/apps/api"
pnpm -s build

echo
echo "DONE."
echo "API build geçtiyse, root build:"
echo "  cd $ROOT && pnpm -s build"
