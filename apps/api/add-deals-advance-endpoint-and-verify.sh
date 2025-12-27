#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/deals/deals.controller.ts" ] || { echo "HATA: src/deals/deals.controller.ts yok."; exit 1; }
[ -f "src/deals/deals.engine.ts" ] || { echo "HATA: src/deals/deals.engine.ts yok."; exit 1; }
[ -f "src/deals/deals.service.ts" ] || { echo "HATA: src/deals/deals.service.ts yok."; exit 1; }

echo "==> 1) deals.controller.ts: POST :id/advance endpoint'i yoksa ekle (idempotent)"

node - <<'NODE'
const fs = require("fs");
const p = "src/deals/deals.controller.ts";
let t = fs.readFileSync(p, "utf8");

// advance metodu zaten varsa çık
if (/\badvance\s*\(/.test(t) && /Post\(['"]\:id\/advance['"]\)/.test(t)) {
  console.log("==> advance endpoint zaten var, dokunulmadı.");
  process.exit(0);
}

// DealEvent importu var mı?
if (!t.includes("DealEvent")) {
  // deals.engine importuna ekle
  if (t.match(/from\s+['"]\.\/deals\.engine['"];?/)) {
    t = t.replace(/from\s+['"]\.\/deals\.engine['"];?/,
      (m) => m); // no-op (aşağıda import satırını sağlam ekleyeceğiz)
  }

  // Eğer deals.engine importu yoksa ekle
  if (!t.includes("from './deals.engine'")) {
    // DealsService importunun altına ekle
    t = t.replace(/import\s+\{\s*DealsService\s*\}\s+from\s+['"]\.\/deals\.service['"];\s*\n/,
      (m) => m + `import { DealEvent } from './deals.engine';\n`);
  } else {
    // Var ama DealEvent yoksa genişlet
    t = t.replace(/import\s+\{\s*([^}]+)\s*\}\s+from\s+['"]\.\/deals\.engine['"];\s*\n/,
      (m, inner) => {
        if (inner.includes("DealEvent")) return m;
        return `import { ${inner.trim().replace(/\s+/g," " )}, DealEvent } from './deals.engine';\n`;
      });
  }
}

// Controller importlarında Body/Param/Post var mı?
if (!t.includes("Body") || !t.includes("Param") || !t.includes("Post")) {
  // Nest import satırını genişlet
  t = t.replace(/import\s+\{\s*([^}]+)\s*\}\s+from\s+['"]@nestjs\/common['"];\s*\n/,
    (m, inner) => {
      const parts = inner.split(",").map(s => s.trim()).filter(Boolean);
      const need = ["Body","Param","Post"].filter(x => !parts.includes(x));
      if (!need.length) return m;
      return `import { ${[...parts, ...need].join(", ")} } from '@nestjs/common';\n`;
    });
}

// advance methodu ekle: class kapanışından hemen önce
const classCloseIdx = t.lastIndexOf("}");
if (classCloseIdx === -1) {
  console.error("HATA: controller class kapanışı bulunamadı.");
  process.exit(1);
}

const method = `

  @Post(':id/advance')
  advance(@Param('id') id: string, @Body() body: { event: DealEvent }) {
    return this.deals.advanceDeal(id, body.event);
  }
`;

t = t.slice(0, classCloseIdx) + method + "\n" + t.slice(classCloseIdx);

fs.writeFileSync(p, t, "utf8");
console.log("==> advance endpoint eklendi.");
NODE

echo
echo "==> 2) Build"
pnpm -s build

echo
echo "==> 3) 3001 kill + dist'ten background başlat"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

export PORT=3001
LOG=".tmp-api-dist.log"
rm -f "$LOG"

MAIN="dist/src/main.js"
[ -f "$MAIN" ] || { echo "HATA: $MAIN yok."; exit 1; }

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
echo "==> 4) Verify: advance route artık var mı?"
curl -i -X POST "http://localhost:3001/deals/test-id/advance" \
  -H "Content-Type: application/json" \
  -d '{"event":"QUESTIONS_COMPLETED"}' || true

echo
echo "==> DONE"
echo "Beklenen: 'Cannot POST' değil, controller'a düşen bir hata (örn: Deal not found)."
echo
echo "API'yi kapatmak için:"
echo "  kill $API_PID"
echo
echo "Log:"
echo "  tail -n 120 $LOG"
