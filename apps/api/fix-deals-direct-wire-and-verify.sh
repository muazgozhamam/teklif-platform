#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/app.module.ts" ] || { echo "HATA: src/app.module.ts yok."; exit 1; }
[ -f "src/deals/deals.controller.ts" ] || { echo "HATA: src/deals/deals.controller.ts yok."; exit 1; }
[ -f "src/deals/deals.service.ts" ] || { echo "HATA: src/deals/deals.service.ts yok."; exit 1; }
[ -f "src/prisma/prisma.module.ts" ] || { echo "HATA: src/prisma/prisma.module.ts yok."; exit 1; }

echo "==> 1) src/app.module.ts: DealsController + DealsService direct wire ediliyor (idempotent)"

node - <<'NODE'
const fs = require("fs");
const p = "src/app.module.ts";
let t = fs.readFileSync(p, "utf8");

function ensureImport(stmt) {
  if (t.includes(stmt)) return;
  const imports = [...t.matchAll(/^import .*;$/gm)];
  if (imports.length) {
    const last = imports[imports.length - 1];
    const idx = last.index + last[0].length;
    t = t.slice(0, idx) + "\n" + stmt + t.slice(idx);
  } else {
    t = stmt + "\n" + t;
  }
}

// Importlar
ensureImport(`import { PrismaModule } from './prisma/prisma.module';`);
ensureImport(`import { DealsController } from './deals/deals.controller';`);
ensureImport(`import { DealsService } from './deals/deals.service';`);

// @Module bloğu
const m = t.match(/@Module\s*\(\s*\{[\s\S]*?\}\s*\)\s*\nexport\s+class\s+AppModule/m);
if (!m) {
  console.error("HATA: @Module({...}) export class AppModule bloğu bulunamadı.");
  process.exit(1);
}
let block = m[0];

// helper: array alanına eleman ekle
function addToArrayField(src, field, item) {
  const re = new RegExp(`${field}\\s*:\\s*\\[([\\s\\S]*?)\\]`, "m");
  if (re.test(src)) {
    return src.replace(re, (mm, inner) => {
      if (inner.includes(item)) return mm;
      const innerTrimRight = inner.replace(/\s+$/,"");
      const needsComma = innerTrimRight.trim() !== "" && !innerTrimRight.trim().endsWith(",");
      const glue = innerTrimRight.trim() === "" ? item : `${innerTrimRight}${needsComma ? "," : ""} ${item}`;
      return `${field}: [${glue}]`;
    });
  } else {
    // alan yoksa ekle
    return src.replace(/@Module\s*\(\s*\{\s*/m, (mm) => `${mm}\n  ${field}: [${item}],\n`);
  }
}

// imports -> PrismaModule
block = addToArrayField(block, "imports", "PrismaModule");
// controllers -> DealsController
block = addToArrayField(block, "controllers", "DealsController");
// providers -> DealsService
block = addToArrayField(block, "providers", "DealsService");

t = t.replace(m[0], block);

fs.writeFileSync(p, t, "utf8");
console.log("==> app.module.ts patched (direct wiring applied).");
NODE

echo
echo "==> 2) Build"
pnpm -s build

echo
echo "==> 3) 3001 dinleyen process'i kill"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
else
  echo "   - 3001 listen eden process yok"
fi

echo
echo "==> 4) dist'ten BACKGROUND başlat + verify"
export PORT=3001
LOG=".tmp-api-dist.log"
rm -f "$LOG"

MAIN=""
if [ -f "dist/src/main.js" ]; then MAIN="dist/src/main.js"; fi
if [ -z "$MAIN" ] && [ -f "dist/main.js" ]; then MAIN="dist/main.js"; fi
if [ -z "$MAIN" ]; then
  echo "HATA: dist içinde main.js bulunamadı."
  find dist -maxdepth 3 -name "main.js" -print
  exit 1
fi

node "$MAIN" >"$LOG" 2>&1 &
API_PID=$!
echo "   - API_PID=$API_PID"
echo "   - Log: $LOG"

# health bekle
for i in 1 2 3 4 5; do
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3001/health" | grep -q "200"; then
    break
  fi
  sleep 1
done

echo
echo "Health:"
curl -i "http://localhost:3001/health" || true

echo
echo "Deals advance route test:"
curl -i -X POST "http://localhost:3001/deals/test-id/advance" \
  -H "Content-Type: application/json" \
  -d '{"event":"QUESTIONS_COMPLETED"}' || true

echo
echo "==> DONE"
echo "Beklenen: Artık 'Cannot POST /deals/...' değil; controller'a düşüp 'Deal not found' benzeri mesaj."
echo
echo "API'yi kapatmak için:"
echo "  kill $API_PID"
echo
echo "Log bakmak için:"
echo "  tail -n 120 $LOG"
