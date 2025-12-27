#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/deals/deals.service.ts" ] || { echo "HATA: src/deals/deals.service.ts yok."; exit 1; }
[ -f "src/leads/leads.service.ts" ] || { echo "HATA: src/leads/leads.service.ts yok."; exit 1; }

echo "==> 1) DealsService.ensureForLead: upsert + schema default status (idempotent replace)"

node - <<'NODE'
const fs = require("fs");
const p = "src/deals/deals.service.ts";
let t = fs.readFileSync(p, "utf8");

// Ensure method exists; if exists, replace body with upsert-safe version
const re = /async\s+ensureForLead\s*\(\s*leadId:\s*string\s*\)\s*\{[\s\S]*?\n\s*\}/m;

const impl = `async ensureForLead(leadId: string) {
    // leadId unique olduğundan en temiz yol: upsert
    return this.prisma.deal.upsert({
      where: { leadId },
      update: {},
      create: { leadId },
    });
  }`;

if (re.test(t)) {
  t = t.replace(re, impl);
  console.log("==> ensureForLead bulundu, upsert implementasyonu ile güncellendi.");
} else {
  // add method before last }
  const idx = t.lastIndexOf("}");
  if (idx === -1) throw new Error("DealsService class kapanışı bulunamadı");
  t = t.slice(0, idx) + "\n\n  " + impl + "\n" + t.slice(idx);
  console.log("==> ensureForLead yoktu, eklendi (upsert).");
}

fs.writeFileSync(p, t, "utf8");
NODE

echo
echo "==> 2) LeadsService.create: return lead öncesi ensureForLead çağrısını garanti et (idempotent)"

node - <<'NODE'
const fs = require("fs");
const p = "src/leads/leads.service.ts";
let t = fs.readFileSync(p, "utf8");

if (!t.includes("dealsService")) {
  console.error("HATA: LeadsService içinde dealsService field'i yok. Constructor DI eksik olabilir.");
  process.exit(2);
}

// Zaten çağırıyorsa çık
if (t.includes("this.dealsService.ensureForLead(")) {
  console.log("==> LeadsService: ensureForLead çağrısı zaten var.");
  process.exit(0);
}

// return lead; öncesine ekle
const marker = /return\s+lead\s*;/;
if (!marker.test(t)) {
  console.error("HATA: leads.service.ts içinde 'return lead;' bulunamadı. Patch için farklı pattern gerekir.");
  process.exit(1);
}

t = t.replace(marker, (m) => `await this.dealsService.ensureForLead(lead.id);\n    ${m}`);

fs.writeFileSync(p, t, "utf8");
console.log("==> LeadsService.create patched (ensureForLead inserted).");
NODE

echo
echo "==> 3) Build"
pnpm -s build

echo
echo "==> 4) 3001 kill + dist'ten background API başlat"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

export PORT=3001
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
echo "==> 5) E2E: Lead oluştur -> Deal by lead -> advance"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"E2E lead->deal upsert"}')"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id)' "$LEAD_JSON")"
echo "   LEAD_ID=$LEAD_ID"

DEAL_JSON="$(curl -fsS "$BASE/deals/by-lead/$LEAD_ID")"
echo "Deal body: $DEAL_JSON"
DEAL_ID="$(node -e 'const j=JSON.parse(process.argv[1]); const d=j.deal||j; process.stdout.write(d.id)' "$DEAL_JSON")"
echo "   DEAL_ID=$DEAL_ID"

echo
echo "Advance QUESTIONS_COMPLETED:"
ADV_JSON="$(curl -fsS -X POST "$BASE/deals/$DEAL_ID/advance" -H "Content-Type: application/json" -d '{"event":"QUESTIONS_COMPLETED"}')"
echo "$ADV_JSON"

echo
echo "==> DONE"
echo "API background çalışıyor. Kapatmak için: kill $API_PID"
