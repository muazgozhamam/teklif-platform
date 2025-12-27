#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
BASE_URL="${BASE_URL:-http://localhost:3001}"

echo "==> ROOT=$ROOT"
echo "==> API_DIR=$API_DIR"
echo "==> BASE_URL=$BASE_URL"
echo

echo "==> 0) Load .env (apps/api/.env)"
if [ -f "$API_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$API_DIR/.env"
  set +a
fi
if [ -z "${DATABASE_URL:-}" ]; then
  echo "HATA: DATABASE_URL set değil. apps/api/.env kontrol et."
  exit 1
fi
echo "OK: DATABASE_URL set"
echo

echo "==> 1) Ensure DevSeedModule + main.ts patch (idempotent)"
node <<'NODE'
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const API_SRC = path.join(ROOT, 'apps', 'api', 'src');

function findFirstExisting(paths) {
  for (const p of paths) if (fs.existsSync(p)) return p;
  return null;
}

function listFiles(dir) {
  const out = [];
  const st = fs.statSync(dir);
  if (!st.isDirectory()) return out;
  for (const ent of fs.readdirSync(dir)) {
    const full = path.join(dir, ent);
    const s = fs.statSync(full);
    if (s.isDirectory()) out.push(...listFiles(full));
    else out.push(full);
  }
  return out;
}

function findMainTs() {
  // en sık lokasyonlar
  const candidates = [
    path.join(API_SRC, 'main.ts'),
    path.join(API_SRC, 'src', 'main.ts'),
  ];
  const direct = findFirstExisting(candidates);
  if (direct) return direct;

  // fallback: src altında main.ts ara
  const all = listFiles(API_SRC).filter(f => f.endsWith('main.ts'));
  return all.length ? all[0] : null;
}

function ensureImport(src, what, from) {
  const importRe = new RegExp(`import\\s*\\{\\s*${what}\\s*\\}\\s*from\\s*['"]${from}['"]\\s*;`);
  if (importRe.test(src)) return src;

  // import block sonuna ekle
  const allImports = src.match(/^(import[\s\S]*?\n)(?!import)/m);
  const line = `import { ${what} } from '${from}';\n`;
  if (allImports) {
    const idx = allImports[1].length;
    return src.slice(0, idx) + line + src.slice(idx);
  }
  // hiç import yoksa dosya başına
  return line + src;
}

function patchAppModule(appModulePath) {
  let src = fs.readFileSync(appModulePath, 'utf8');

  // DevSeedModule import
  src = ensureImport(src, 'DevSeedModule', './dev-seed/dev-seed.module');

  // @Module({ imports: [...] }) içine ekle
  // imports array'i bul
  const moduleRe = /@Module\s*\(\s*\{[\s\S]*?\}\s*\)\s*export\s+class\s+\w+/m;
  if (!moduleRe.test(src)) {
    console.log(`WARN: app.module.ts içinde @Module bloğu bulunamadı: ${appModulePath}`);
    fs.writeFileSync(appModulePath, src, 'utf8');
    return;
  }

  // imports: [ ... ] yakala
  const importsArrRe = /imports\s*:\s*\[([\s\S]*?)\]/m;
  if (!importsArrRe.test(src)) {
    // imports yoksa eklemeyi dene: @Module({ ... })
    src = src.replace(/@Module\s*\(\s*\{\s*/m, m => m + `imports: [DevSeedModule],\n`);
    fs.writeFileSync(appModulePath, src, 'utf8');
    return;
  }

  src = src.replace(importsArrRe, (m, inside) => {
    if (/\bDevSeedModule\b/.test(inside)) return m;
    const trimmed = inside.trim();
    if (!trimmed) return `imports: [DevSeedModule]`;
    // sona virgül konusunu normalize et
    const hasTrailingComma = /,\s*$/.test(inside);
    const newInside = hasTrailingComma ? `${inside}\n  DevSeedModule,` : `${inside.trimEnd()},\n  DevSeedModule,`;
    return `imports: [${newInside}\n]`;
  });

  fs.writeFileSync(appModulePath, src, 'utf8');
}

function patchMainTs(mainPath) {
  let src = fs.readFileSync(mainPath, 'utf8');

  // Importlar
  src = ensureImport(src, 'DevSeedModule', './dev-seed/dev-seed.module');
  src = ensureImport(src, 'DevSeedService', './dev-seed/dev-seed.service');

  // Seed bloğu zaten var mı?
  if (/DEV_SEED\s*===?\s*['"]1['"]/.test(src) || /process\.env\.DEV_SEED/.test(src) && /DevSeedService/.test(src) && /seed\(\)/.test(src)) {
    fs.writeFileSync(mainPath, src, 'utf8');
    return;
  }

  // AppModule ile NestFactory.create(...) assignment satırını yakala (farklı formatları tolere et)
  // Örn:
  // const app = await NestFactory.create(AppModule);
  // const app = await NestFactory.create<NestExpressApplication>(AppModule, { ... });
  // const app = await NestFactory.create(
  //   AppModule,
  //   ...
  // );
  const createRe = /(const|let)\s+(\w+)\s*=\s*await\s+NestFactory\.\w+\s*(?:<[^>]*>)?\s*\(\s*AppModule\b[\s\S]*?\)\s*;\s*/m;

  const match = src.match(createRe);
  if (!match) {
    // Daha kaba fallback: AppModule geçen ilk NestFactory satırının hemen altına ekle
    const roughRe = /NestFactory[\s\S]*?AppModule[\s\S]*?;\s*/m;
    const m2 = src.match(roughRe);
    if (!m2) {
      console.error(`HATA: main.ts içinde NestFactory + AppModule satırı bulunamadı. Dosya: ${mainPath}`);
      // debug: ilk 80 satırı bas
      console.error('--- main.ts head(120) ---');
      console.error(src.split('\n').slice(0, 120).join('\n'));
      process.exit(1);
    }
    const insertAt = m2.index + m2[0].length;
    const seedBlock =
`\n  // DEV SEED (idempotent) — run only when DEV_SEED=1
  if (process.env.DEV_SEED === '1') {
    try {
      await app.get(DevSeedService).seed();
      // eslint-disable-next-line no-console
      console.log('[dev-seed] seeded');
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn('[dev-seed] seed failed:', e?.message ?? e);
    }
  }\n`;
    // Bu fallback app değişkeni "app" varsayar; riskli ama yine de çoğu projede doğru.
    src = src.slice(0, insertAt) + seedBlock + src.slice(insertAt);
    fs.writeFileSync(mainPath, src, 'utf8');
    return;
  }

  const appVar = match[2];
  const insertAt = match.index + match[0].length;

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

  src = src.slice(0, insertAt) + seedBlock + src.slice(insertAt);
  fs.writeFileSync(mainPath, src, 'utf8');
}

const mainTs = findMainTs();
if (!mainTs) {
  console.error('HATA: apps/api/src altında main.ts bulunamadı.');
  process.exit(1);
}

// app.module.ts bul (en tipik)
const appModuleCandidates = [
  path.join(API_SRC, 'app.module.ts'),
  path.join(API_SRC, 'src', 'app.module.ts'),
];
let appModule = findFirstExisting(appModuleCandidates);
if (!appModule) {
  // fallback: src altında app.module.ts ara
  const all = listFiles(API_SRC).filter(f => f.endsWith('app.module.ts'));
  appModule = all.length ? all[0] : null;
}

patchMainTs(mainTs);
if (appModule) patchAppModule(appModule);

console.log('OK: patched main.ts:', mainTs);
if (appModule) console.log('OK: patched app.module.ts:', appModule);
else console.log('WARN: app.module.ts bulunamadı, sadece main.ts patchlendi.');
NODE

echo

echo "==> 2) Install deps (root)"
cd "$ROOT"
pnpm -s i
echo

echo "==> 3) Prisma generate + build (api)"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
echo

echo "==> 4) Start API (manual) + E2E hint"
echo "API'yi ayrı terminalde başlat:"
echo "  cd $API_DIR && DEV_SEED=1 pnpm start:dev"
echo
echo "Sonra test:"
echo "  curl -i $BASE_URL/health"
echo "  curl -i $BASE_URL/docs"
