#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$ROOT/apps/api/src/main.ts"

if [ ! -f "$MAIN" ]; then
  echo "HATA: main.ts yok: $MAIN"
  exit 1
fi

echo "==> FIX main.ts (remove DevSeedModule + stray braces): $MAIN"

MAIN="$MAIN" node <<'NODE'
const fs = require('fs');

const p = process.env.MAIN;
let s = fs.readFileSync(p, 'utf8');
let lines = s.split('\n');

// 1) DevSeedModule geçen tüm import/kullanım satırlarını kaldır
lines = lines.filter(l => !l.includes('DevSeedModule'));

// 2) NestFactory.create(...) satırını NestFactory.create(AppModule) yap
// (DevSeedModule içeren conditional create varyasyonlarını da yakalamak için geniş regex)
lines = lines.map(l => {
  if (l.includes('NestFactory.create(')) {
    // aynı satırda bitiyorsa
    return l
      .replace(/NestFactory\.create\([\s\S]*?\)/, 'NestFactory.create(AppModule)');
  }
  return l;
});

// 3) Eğer create ifadesi çok satırlıysa (nadir): tüm dosyada genel replace
let joined = lines.join('\n');
joined = joined.replace(
  /NestFactory\.create\(\s*isDev\s*\?\s*\{[\s\S]*?\}\s*:\s*AppModule\s*\)/g,
  'NestFactory.create(AppModule)'
);
joined = joined.replace(
  /NestFactory\.create\(\s*\{[\s\S]*?module\s*:\s*AppModule[\s\S]*?\}\s*\)/g,
  'NestFactory.create(AppModule)'
);

// 4) "const app" (veya NestFactory) satırından önceki tek başına "}" satırlarını temizle
lines = joined.split('\n');
let anchor = lines.findIndex(l => /const\s+app\s*=/.test(l) || /await\s+NestFactory\./.test(l));
if (anchor === -1) anchor = lines.length;

const cleaned = [];
for (let i = 0; i < lines.length; i++) {
  const l = lines[i];
  if (i < anchor && /^\s*}\s*$/.test(l)) continue;
  cleaned.push(l);
}
joined = cleaned.join('\n');

// 5) Import satırlarını dedupe et (aynı import iki kez kalmasın)
const out = [];
const seen = new Set();
for (const l of joined.split('\n')) {
  if (/^\s*import\s+/.test(l)) {
    if (seen.has(l)) continue;
    seen.add(l);
  }
  out.push(l);
}

fs.writeFileSync(p, out.join('\n'), 'utf8');
console.log("OK: cleaned main.ts (DevSeedModule removed, create normalized, stray braces cleaned)");
NODE

echo "==> Build only API to verify"
cd "$ROOT/apps/api"
pnpm -s build

echo
echo "DONE. Root build:"
echo "  cd $ROOT && pnpm -s build"
