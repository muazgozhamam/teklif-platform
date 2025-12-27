#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
MAIN="$API_DIR/src/main.ts"
SVC="$API_DIR/src/dev-seed/dev-seed.service.ts"

echo "==> ROOT=$ROOT"
echo "==> MAIN=$MAIN"
echo "==> SVC =$SVC"

[ -f "$MAIN" ] || { echo "HATA: main.ts yok"; exit 1; }
[ -f "$SVC" ]  || { echo "HATA: dev-seed.service.ts yok"; exit 1; }

node <<'NODE'
const fs = require('fs');

const mainPath = process.env.MAIN;
const svcPath  = process.env.SVC;

function writeIfChanged(path, next) {
  const prev = fs.readFileSync(path, 'utf8');
  if (prev === next) {
    console.log(`OK: no change -> ${path}`);
    return;
  }
  fs.writeFileSync(path, next, 'utf8');
  console.log(`OK: patched -> ${path}`);
}

//
// 1) main.ts: DEV_SEED block içindeki ".seed()" çağrısını kaldır
//
let main = fs.readFileSync(mainPath, 'utf8');

// a) seed() çağrısını direkt değiştir: .seed() => .onModuleInit()
//    (istersek tamamen kaldırırız; ama en risksiz: komple kaldırmak)
// b) Biz komple kaldırıyoruz: if (process.env.DEV_SEED === '1') { ... } bloğunu sil.
main = main.replace(
  /\n\s*\/\/ Optional dev seed \(only when DEV_SEED=1\)[\s\S]*?\n\s*}\n/gm,
  '\n'
);

// Eğer yukarıdaki pattern tutmazsa, daha genel bir silme denemesi:
main = main.replace(
  /\n\s*if\s*\(\s*process\.env\.DEV_SEED\s*===\s*['"]1['"]\s*\)\s*\{[\s\S]*?\n\s*\}\n/gm,
  '\n'
);

// main.ts içinde import { DevSeedService } varsa ama artık kullanılmıyorsa kaldır.
main = main.replace(/\nimport\s+\{\s*DevSeedService\s*\}\s+from\s+['"][^'"]+['"];\s*\n/g, '\n');

writeIfChanged(mainPath, main);

//
// 2) DevSeedService: onModuleInit içine DEV_SEED guard ekle
//
let svc = fs.readFileSync(svcPath, 'utf8');

// onModuleInit başında guard var mı kontrol et
const hasGuard = /async\s+onModuleInit\s*\(\s*\)\s*\{\s*\n\s*if\s*\(\s*process\.env\.DEV_SEED\s*!==\s*['"]1['"]\s*\)\s*\{\s*\n\s*return;\s*\n\s*\}\s*/m.test(svc);

if (!hasGuard) {
  // async onModuleInit() {  => async onModuleInit() { if (DEV_SEED!== '1') return; ... }
  svc = svc.replace(
    /async\s+onModuleInit\s*\(\s*\)\s*\{\s*\n/m,
    match => match + "    if (process.env.DEV_SEED !== '1') {\n      return;\n    }\n\n"
  );
}

writeIfChanged(svcPath, svc);

NODE

echo
echo "==> Clean API dist (safe) + build API"
cd "$API_DIR"
rm -rf dist
pnpm -s build

echo
echo "DONE."
echo "Dev çalıştır:"
echo "  cd $API_DIR && DEV_SEED=1 pnpm start:dev"
echo "Test:"
echo "  curl -i http://localhost:3001/health"
echo "  curl -i http://localhost:3001/docs"
