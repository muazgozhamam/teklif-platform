#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"
LOG=".tmp-api-dist.log"

[ -f "src/leads/leads.service.ts" ] || { echo "HATA: src/leads/leads.service.ts yok."; exit 1; }

echo "==> 1) leads.service.ts içinde ensureForLead nerede?"
grep -n "ensureForLead" -n src/leads/leads.service.ts || true

echo
echo "==> 2) leads.service.ts içinde create metodundan küçük bir snapshot"
# create metodunu bulup 60 satır göster
node - <<'NODE'
const fs=require("fs");
const t=fs.readFileSync("src/leads/leads.service.ts","utf8").split("\n");
let i=t.findIndex(l=>/async\s+create\s*\(/.test(l));
if(i<0) i=t.findIndex(l=>/\bcreate\s*\(/.test(l));
if(i<0){ console.log("create(...) bulunamadı"); process.exit(0); }
const start=Math.max(0,i-5), end=Math.min(t.length,i+80);
console.log(t.slice(start,end).map((l,idx)=>String(start+idx+1).padStart(4," ")+": "+l).join("\n"));
NODE

echo
echo "==> 3) API'den yeni lead oluştur (body only) + leadId"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"diagnose lead->deal"}')"
echo "Lead: $LEAD_JSON"
LEAD_ID="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id||"")' "$LEAD_JSON")"
echo "LEAD_ID=$LEAD_ID"

echo
echo "==> 4) DB'de Deal var mı? (Prisma ile leadId üzerinden sorgu)"
node - <<'NODE'
const path=require("path");
const fs=require("fs");

// .env yükle
const dotenv=require("dotenv");
dotenv.config({ path: path.resolve(process.cwd(), ".env") });

const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

(async () => {
  const leadId = process.env._LEAD_ID;
  const deal = await prisma.deal.findUnique({ where: { leadId } });
  console.log("DB deal:", deal);
  await prisma.$disconnect();
})().catch(async (e) => {
  console.error("DB CHECK ERROR:", e);
  process.exit(1);
});
NODE
BASH_ENV=<(echo "export _LEAD_ID=$LEAD_ID") node -e 'process.exit(0)' >/dev/null 2>&1 || true

# Yukarıdaki env trick yerine en garanti yöntem:
export _LEAD_ID="$LEAD_ID"
node - <<'NODE'
const path=require("path");
require("dotenv").config({ path: path.resolve(process.cwd(), ".env") });
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
(async () => {
  const leadId = process.env._LEAD_ID;
  const deal = await prisma.deal.findUnique({ where: { leadId } });
  console.log("DB deal:", deal);
  await prisma.$disconnect();
})().catch(async (e) => {
  console.error("DB CHECK ERROR:", e);
  process.exit(1);
});
NODE
unset _LEAD_ID

echo
echo "==> 5) API log son 120 satır (hata var mı?)"
if [ -f "$LOG" ]; then
  tail -n 120 "$LOG" || true
else
  echo "UYARI: $LOG yok."
fi

echo
echo "==> DONE"
