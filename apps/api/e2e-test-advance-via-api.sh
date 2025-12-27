#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"

echo "==> 0) Health"
curl -fsS "$BASE/health" >/dev/null
echo "   OK"

echo
echo "==> 1) Lead create (POST /leads)"
LEAD_JSON="$(curl -fsS -X POST "$BASE/leads" \
  -H "Content-Type: application/json" \
  -d '{"initialText":"E2E test lead - create deal"}'
)"

LEAD_ID="$(node - <<'NODE'
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");
const j = JSON.parse(input);
const id = j.id || j.lead?.id || j.data?.id;
if (!id) { console.error("LEAD_ID parse edilemedi. Response:", j); process.exit(2); }
process.stdout.write(id);
NODE
<<<"$LEAD_JSON")"

echo "   LEAD_ID=$LEAD_ID"

echo
echo "==> 2) Deal by lead (GET /deals/by-lead/:leadId)"
DEAL_JSON="$(curl -fsS "$BASE/deals/by-lead/$LEAD_ID" || true)"

if [ -z "${DEAL_JSON}" ]; then
  echo "HATA: /deals/by-lead endpoint boş döndü veya erişilemedi."
  echo "Not: Bu endpoint yoksa, DealsController'da path farklı olabilir."
  exit 1
fi

DEAL_ID="$(node - <<'NODE'
const fs = require("fs");
const input = fs.readFileSync(0, "utf8");
const j = JSON.parse(input);

// response tek deal veya {deal: ...} gibi olabilir
const d = j.deal || j;
const id = d.id;
if (!id) { console.error("DEAL_ID parse edilemedi. Response:", j); process.exit(2); }
process.stdout.write(id);
NODE
<<<"$DEAL_JSON")"

echo "   DEAL_ID=$DEAL_ID"

echo
echo "==> 3) advance QUESTIONS_COMPLETED (POST /deals/:id/advance)"
curl -fsS -X POST "$BASE/deals/$DEAL_ID/advance" \
  -H "Content-Type: application/json" \
  -d '{"event":"QUESTIONS_COMPLETED"}'

echo
echo
echo "==> DONE"
echo "Beklenen: response içindeki status QUALIFIED olmalı (DRAFT -> QUALIFIED)."
