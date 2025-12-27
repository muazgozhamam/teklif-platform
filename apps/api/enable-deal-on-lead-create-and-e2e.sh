#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"
LOG=".tmp-api-dist.log"

[ -f "src/leads/leads.service.ts" ] || { echo "HATA: src/leads/leads.service.ts yok."; exit 1; }

echo "==> 1) leads.service.ts: create() içine ensureForLead ekle (idempotent)"

node - <<'NODE'
const fs=require("fs");
const p="src/leads/leads.service.ts";
let t=fs.readFileSync(p,"utf8");

// Zaten create içinde ensureForLead var mı?
const createBlock = /async\s+create\s*\([\s\S]*?\n\s*\}\n/m;
const m = t.match(createBlock);
if (!m) { console.error("HATA: create() bloğu bulunamadı"); process.exit(1); }

const block = m[0];
if (block.includes("this.dealsService.ensureForLead(")) {
  console.log("==> create() içinde ensureForLead zaten var. Dokunulmadı.");
  process.exit(0);
}

// return lead; öncesine ekle
if (!/return\s+lead\s*;/.test(block)) {
  console.error("HATA: create() içinde 'return lead;' bulunamadı");
  process.exit(1);
}

const patched = block.replace(/return\s+lead\s*;/, "await this.dealsService.ensureForLead(lead.id);\n    return lead;");
t = t.replace(block, patched);

fs.writeFileSync(p, t, "utf8");
console.log("==> create() patched: ensureForLead eklendi.");
NODE

echo
echo "==> 2) Build"
pnpm -s build

echo
echo "==> 3) 3001 kill + dist'ten background API start"
PIDS="$(lsof -nP -t -iTCP:3001 -sTCP:LISTEN || true)"
if [ -n "${PIDS}" ]; then
  echo "   - Killing PID(s): ${PIDS}"
  kill -9 ${PIDS} || true
fi

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
echo "==> 4) E2E: Lead create -> Deal by lead (beklenen 200)"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"E2E lead create => deal create"}')"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id)' "$LEAD_JSON")"
echo "   LEAD_ID=$LEAD_ID"

echo
echo "Deal by lead:"
curl -i "$BASE/deals/by-lead/$LEAD_ID" || true

echo
echo "==> DONE"
echo "API background çalışıyor. Kapatmak için: kill $API_PID"
