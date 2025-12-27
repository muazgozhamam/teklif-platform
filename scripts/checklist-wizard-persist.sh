#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
API_DIR="$ROOT/apps/api"
CTRL="$API_DIR/src/leads/leads.controller.ts"
SVC="$API_DIR/src/leads/leads.service.ts"
SCHEMA="$API_DIR/prisma/schema.prisma"
BASE="${BASE_URL:-http://localhost:3001}"

echo "==> 0) Files exist?"
for f in "$CTRL" "$SVC" "$SCHEMA"; do
  [[ -f "$f" ]] && echo "OK: $f" || (echo "MISSING: $f" && exit 1)
done

echo
echo "==> 1) Controller wizard/answer route -> service call"
python3 - <<'PY' "$CTRL"
import re, sys
txt=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r"@Post\(\s*['\"][^'\"]*wizard/answer['\"]\s*\)[\s\S]{0,300}?return\s+this\.leads\.([A-Za-z_]\w*)\(", txt)
print("serviceMethod=" + (m.group(1) if m else "NOT_FOUND"))
PY

echo
echo "==> 2) LeadsService wizardAnswer signature (param names)"
python3 - <<'PY' "$SVC"
import re, sys
txt=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r"\basync\s+wizardAnswer\s*\(([^)]*)\)\s*\{", txt)
if not m:
  print("wizardAnswerSignature=NOT_FOUND")
  raise SystemExit(0)
sig=m.group(1)
names=re.findall(r"\b([A-Za-z_]\w*)\s*:", sig)
print("wizardAnswerParams=" + ",".join(names))
PY

echo
echo "==> 3) Prisma: is Deal.leadId unique? (needed for upsert(where: {leadId}))"
python3 - <<'PY' "$SCHEMA"
import re, sys
txt=open(sys.argv[1],encoding="utf-8").read()
# naive: find model Deal block
m=re.search(r"model\s+Deal\s*\{([\s\S]*?)\n\}", txt)
if not m:
  print("dealModel=NOT_FOUND")
  raise SystemExit(0)
block=m.group(1)
lead_line=None
for ln in block.splitlines():
  if re.search(r"\bleadId\b", ln):
    lead_line=ln.strip()
    break
print("dealLeadIdLine=" + (lead_line or "NOT_FOUND"))
print("dealLeadIdHasUnique=" + ("true" if lead_line and "@unique" in lead_line else "false"))
PY

echo
echo "==> 4) Runtime checks (API health + wizard run + DB snapshot)"
curl -sS "$BASE/health" >/dev/null && echo "OK: health" || (echo "FAIL: health" && exit 1)

# create lead
LEAD_ID="$(curl -sS -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"checklist wizard persist"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")"
echo "leadId=$LEAD_ID"

echo "==> 4.1) DB: Deal BEFORE wizardAnswer?"
node - <<'NODE' "$API_DIR" "$LEAD_ID"
const apiDir = process.argv[2];
const leadId = process.argv[3];
process.chdir(apiDir);
const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();
(async () => {
  const deal = await p.deal.findFirst({ where: { leadId }, select: {id:true,status:true,city:true,district:true,type:true,rooms:true} });
  console.log(JSON.stringify(deal, null, 2));
  await p.$disconnect();
})().catch(async (e)=>{console.error(e); await p.$disconnect(); process.exit(1);});
NODE

echo "==> 4.2) Wizard answer one step (city) + DB snapshot"
curl -sS -X POST "$BASE/leads/$LEAD_ID/wizard/answer" -H "Content-Type: application/json" -d '{"key":"city","answer":"Konya"}' >/dev/null || true

node - <<'NODE' "$API_DIR" "$LEAD_ID"
const apiDir = process.argv[2];
const leadId = process.argv[3];
process.chdir(apiDir);
const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();
(async () => {
  const deal = await p.deal.findFirst({ where: { leadId }, select: {id:true,status:true,city:true,district:true,type:true,rooms:true} });
  console.log(JSON.stringify(deal, null, 2));
  await p.$disconnect();
})().catch(async (e)=>{console.error(e); await p.$disconnect(); process.exit(1);});
NODE

echo "==> DONE"
