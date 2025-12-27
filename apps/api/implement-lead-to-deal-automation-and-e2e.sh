#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/leads/leads.service.ts" ] || { echo "HATA: src/leads/leads.service.ts yok."; exit 1; }
[ -f "src/deals/deals.service.ts" ] || { echo "HATA: src/deals/deals.service.ts yok."; exit 1; }

echo "==> 1) DealsService: ensureForLead(leadId) ekle (idempotent)"
node - <<'NODE'
const fs = require("fs");
const p = "src/deals/deals.service.ts";
let t = fs.readFileSync(p, "utf8");

if (!t.includes("async ensureForLead(")) {
  const idx = t.lastIndexOf("}");
  if (idx === -1) { console.error("DealsService class kapanışı yok"); process.exit(1); }

  const method = `

  async ensureForLead(leadId: string) {
    // lead'e bağlı en güncel deal varsa döndür
    const existing = await this.prisma.deal.findFirst({
      where: { leadId },
      orderBy: { createdAt: 'desc' as any },
    });
    if (existing) return existing;

    // yoksa oluştur
    return this.prisma.deal.create({
      data: {
        leadId,
        status: 'DRAFT' as any,
        statusChangedAt: new Date(),
      } as any,
    });
  }
`;
  t = t.slice(0, idx) + method + "\n" + t.slice(idx);
  fs.writeFileSync(p, t, "utf8");
  console.log("==> ensureForLead eklendi.");
} else {
  console.log("==> ensureForLead zaten var.");
}
NODE

echo
echo "==> 2) LeadsService: create sonrası ensureForLead çağır (idempotent)"
node - <<'NODE'
const fs = require("fs");
const p = "src/leads/leads.service.ts";
let t = fs.readFileSync(p, "utf8");

// DealsService import var mı? (dist d.ts'de vardı ama yine de garanti)
if (!t.includes("DealsService")) {
  console.error("HATA: LeadsService içinde DealsService referansı yok. Önce DI eklenmeli.");
  process.exit(2);
}

// create metodunda ensure çağrısı var mı?
if (t.includes("ensureForLead(") || t.includes(".ensureForLead(")) {
  console.log("==> LeadsService create içinde ensureForLead zaten çağrılıyor.");
  process.exit(0);
}

// create(...) metodunu yakala: "async create(" bloğunda lead oluşturduktan sonra ekle
// Basit ama pratik yaklaşım: "return lead;" satırını bul ve öncesine insert et.
const marker = /return\s+lead\s*;/;
if (!marker.test(t)) {
  console.error("HATA: leads.service.ts içinde 'return lead;' bulunamadı. Patch için farklı pattern gerekir.");
  process.exit(1);
}

t = t.replace(marker, (m) => `await this.dealsService.ensureForLead(lead.id);\n    ${m}`);

fs.writeFileSync(p, t, "utf8");
console.log("==> LeadsService create patched: ensureForLead after lead create.");
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

# health bekle
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
LEAD_BODY="$(curl -fsS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"E2E lead->deal automation"}')"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); console.log(j.id)' "$LEAD_BODY")"
echo "   LEAD_ID=$LEAD_ID"

DEAL_BODY="$(curl -fsS "$BASE/deals/by-lead/$LEAD_ID")"
DEAL_ID="$(node -e 'const j=JSON.parse(process.argv[1]); console.log((j.deal||j).id)' "$DEAL_BODY")"
echo "   DEAL_ID=$DEAL_ID"

echo
echo "Advance QUESTIONS_COMPLETED:"
curl -fsS -X POST "$BASE/deals/$DEAL_ID/advance" \
  -H "Content-Type: application/json" \
  -d '{"event":"QUESTIONS_COMPLETED"}'

echo
echo "==> DONE"
echo "API background çalışıyor. Kapatmak için: kill $API_PID"
