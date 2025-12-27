#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"

echo "==> 0) Health"
curl -i "$BASE/health" || true

echo
echo "==> 1) Yeni lead oluştur"
LEAD_BODY="$(curl -sS -i -X POST "$BASE/leads" -H "Content-Type: application/json" -d '{"initialText":"debug by-lead 404"}')"
echo "$LEAD_BODY"

LEAD_JSON="$(echo "$LEAD_BODY" | sed -n '/^\r\{0,1\}$/,$p' | tail -n +2 || true)"
# Bazı ortamlarda body ayrımı için daha sağlam:
LEAD_JSON="$(echo "$LEAD_BODY" | awk 'BEGIN{body=0} body{print} /^(\r)?$/{body=1}')"

LEAD_ID="$(node - <<'NODE'
const fs=require("fs");
const s=fs.readFileSync(0,"utf8").trim();
if(!s){ process.exit(2); }
const j=JSON.parse(s);
process.stdout.write(j.id || "");
NODE
<<<"$LEAD_JSON")" || true

echo
echo "==> LEAD_ID=$LEAD_ID"
if [ -z "$LEAD_ID" ]; then
  echo "HATA: Lead ID parse edilemedi."
  exit 1
fi

echo
echo "==> 2) GET /deals/by-lead/:leadId (status + body)"
curl -i "$BASE/deals/by-lead/$LEAD_ID" || true

echo
echo "==> 3) GET /docs içinde deals var mı? (swagger json çekip arıyoruz)"
# Swagger UI HTML olabilir; ama Nest swagger endpoint genelde /docs-json veya /docs-json? Deneyelim
curl -sS "$BASE/docs-json" | grep -i "deals" | head -n 30 || true

echo
echo "==> DONE"
