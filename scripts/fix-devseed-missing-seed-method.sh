#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
SVC="$API_DIR/src/dev-seed/dev-seed.service.ts"

echo "==> ROOT=$ROOT"
echo "==> Service file: $SVC"

if [ ! -f "$SVC" ]; then
  echo "HATA: DevSeedService dosyası bulunamadı: $SVC"
  echo "Bulmak için:"
  echo "  find $API_DIR/src -maxdepth 6 -name '*dev*seed*.service.ts' -o -name '*seed*.service.ts'"
  exit 1
fi

node <<'NODE'
const fs = require('fs');

const svcPath = process.env.SVC || null;
const filePath = svcPath ?? (process.cwd() + '/apps/api/src/dev-seed/dev-seed.service.ts');

let s = fs.readFileSync(filePath, 'utf8');

if (/class\s+DevSeedService\b[\s\S]*?\bseed\s*\(/m.test(s)) {
  console.log("OK: DevSeedService zaten seed() içeriyor. Değişiklik yok.");
  process.exit(0);
}

// class bloğunu bul (basit ve pratik)
const classIdx = s.search(/class\s+DevSeedService\b/);
if (classIdx === -1) {
  console.error("HATA: class DevSeedService bulunamadı. Dosya beklenenden farklı.");
  process.exit(1);
}

// Uygun aday metodları tara
const candidates = [
  'run',
  'seedDev',
  'devSeed',
  'ensure',
  'bootstrap',
  'init',
  'create',
  'createDefault',
  'createDefaults',
  'populate',
  'populateDefaults',
];
let target = null;

for (const name of candidates) {
  const re = new RegExp(`\\basync\\s+${name}\\s*\\(|\\b${name}\\s*\\(`, 'm');
  if (re.test(s)) { target = name; break; }
}

// class kapanışını (son } ) bulmak için kaba ama çoğu projede yeterli:
// DevSeedService class'ından sonra gelen ilk "}" satırı yerine en sona enjekte etmeyeceğiz.
// Daha güvenli: Son "export" öncesi enjekte et veya dosyanın sonundaki son "}"'den hemen önce enjekte et.
// Biz: dosyadaki son "}" karakterinden önce enjekte edeceğiz (genelde class kapanışı).
const lastBrace = s.lastIndexOf('}');
if (lastBrace === -1) {
  console.error("HATA: Dosyada '}' bulunamadı.");
  process.exit(1);
}

const indent = '\n  ';
const body =
  target
    ? `${indent}// Added by script: alias for main.ts DEV_SEED flow\n  async seed() {\n    return this.${target}();\n  }\n`
    : `${indent}// Added by script: alias for main.ts DEV_SEED flow\n  async seed() {\n    // TODO: implement real seeding if needed\n    return;\n  }\n`;

s = s.slice(0, lastBrace) + body + s.slice(lastBrace);

fs.writeFileSync(filePath, s, 'utf8');
console.log(`OK: seed() method added to DevSeedService${target ? ` -> ${target}()` : ' (no-op)'}`);
NODE

echo
echo "==> Build only API to verify"
cd "$API_DIR"
pnpm -s build
echo
echo "DONE."
