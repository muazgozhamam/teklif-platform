#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/leads/leads.service.ts" ] || { echo "HATA: src/leads/leads.service.ts yok."; exit 1; }

echo "==> 1) LeadsService: dealsService DI + create sonrası ensureForLead çağrısını garanti et"
node - <<'NODE'
const fs = require("fs");
const p = "src/leads/leads.service.ts";
let t = fs.readFileSync(p, "utf8");

// 1) DealsService import yoksa ekle
if (!t.includes("from '../deals/deals.service'") && !t.includes('from "../deals/deals.service"')) {
  // PrismaService importunun altına eklemeye çalış
  if (t.includes("from '../prisma/prisma.service'") || t.includes('from "../prisma/prisma.service"')) {
    t = t.replace(
      /(import\s+\{\s*PrismaService\s*\}\s+from\s+['"]\.\.\/prisma\/prisma\.service['"];\s*\n)/,
      `$1import { DealsService } from '../deals/deals.service';\n`
    );
  } else {
    // en üste ekle
    t = `import { DealsService } from '../deals/deals.service';\n` + t;
  }
}

// 2) constructor'da DealsService yoksa ekle
// constructor(...) { ... } şeklini bulup param listesine eklemeye çalış
if (!t.includes("dealsService: DealsService")) {
  t = t.replace(
    /constructor\s*\(\s*([^)]*)\)/m,
    (m, params) => {
      const p2 = params.trim();
      // prisma paramı varsa yanına ekle
      if (p2.includes("PrismaService")) {
        // zaten virgül yönet
        const trimmed = p2.replace(/\s+$/,"");
        const sep = trimmed.endsWith(",") || trimmed.length===0 ? "" : ", ";
        return `constructor(${trimmed}${sep}private dealsService: DealsService)`;
      }
      // prisma yoksa yine ekle (ama bu senaryoda projede prisma vardır)
      const sep = p2.length ? ", " : "";
      return `constructor(${p2}${sep}private dealsService: DealsService)`;
    }
  );
}

// 3) create metodunda ensureForLead call yoksa, return lead; öncesine ekle
if (!t.includes("this.dealsService.ensureForLead(")) {
  const marker = /return\s+lead\s*;/;
  if (!marker.test(t)) {
    console.error("HATA: leads.service.ts içinde 'return lead;' bulunamadı. Patch için farklı pattern gerekir.");
    process.exit(2);
  }
  t = t.replace(marker, (m) => `await this.dealsService.ensureForLead(lead.id);\n    ${m}`);
}

fs.writeFileSync(p, t, "utf8");
console.log("==> leads.service.ts patched (ensureForLead ensured).");
NODE

echo
echo "==> 2) Build"
pnpm -s build

echo
echo "==> 3) API restart (3001 kill + dist background start)"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

LOG=".tmp-api-dist.log"
rm -f "$LOG"

node dist/src/main.js >"$LOG" 2>&1 &
API_PID=$!
echo "   - API_PID=$API_PID"
echo "   - Log: $LOG"

for i in 1 2 3 4 5 6; do
  CODE="$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health" || true)"
  if [ "$CODE" = "200" ]; then break; fi
  sleep 1
done

CODE="$(curl -s -o /dev/null -w "%{http_code}" "$BASE/health" || true)"
if [ "$CODE" != "200" ]; then
  echo "HATA: API kalkmadı. Log:"
  tail -n 120 "$LOG" || true
  echo "Kapat: kill $API_PID"
  exit 1
fi

echo
echo "==> 4) E2E: Lead create -> Deal by lead (beklenen 200) -> advance"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"E2E lead->deal ensure"}')"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id)' "$LEAD_JSON")"
echo "   LEAD_ID=$LEAD_ID"

echo
echo "Deal by lead:"
curl -i "$BASE/deals/by-lead/$LEAD_ID" || true

DEAL_JSON="$(curl -fsS "$BASE/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -e 'const j=JSON.parse(process.argv[1]); const d=j.deal||j; process.stdout.write(d.id)' "$DEAL_JSON")"
echo "   DEAL_ID=$DEAL_ID"

echo
echo "Advance QUESTIONS_COMPLETED:"
curl -i -X POST "$BASE/deals/$DEAL_ID/advance" \
  -H "Content-Type: application/json" \
  -d '{"event":"QUESTIONS_COMPLETED"}' || true

echo
echo "==> DONE"
echo "API background çalışıyor. Kapatmak için: kill $API_PID"
