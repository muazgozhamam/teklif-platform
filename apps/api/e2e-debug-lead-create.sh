#!/usr/bin/env bash
set -euo pipefail

BASE="http://localhost:3001"

echo "==> 0) Health"
curl -fsS "$BASE/health" >/dev/null
echo "   OK"

echo
echo "==> 1) POST /leads (raw capture)"
TMP_BODY=".tmp-lead-create.body"
TMP_HDR=".tmp-lead-create.hdr"
rm -f "$TMP_BODY" "$TMP_HDR"

# -D headers, body ayrı
curl -sS -D "$TMP_HDR" -o "$TMP_BODY" \
  -X POST "$BASE/leads" \
  -H "Content-Type: application/json" \
  -d '{"initialText":"E2E test lead - create deal"}' || true

echo "--- status line ---"
head -n 1 "$TMP_HDR" || true
echo "--- headers (first 30) ---"
sed -n '1,30p' "$TMP_HDR" || true
echo "--- body (raw) ---"
cat "$TMP_BODY" || true
echo
echo "-------------------"

echo
echo "==> 2) Lead ID parse denemesi (JSON ise)"
LEAD_ID="$(node - <<'NODE'
const fs = require("fs");
const body = fs.readFileSync(".tmp-lead-create.body", "utf8").trim();
if (!body) {
  console.error("BODY BOS");
  process.exit(2);
}
try {
  const j = JSON.parse(body);
  const id = j.id || j.lead?.id || j.data?.id;
  if (!id) {
    console.error("JSON var ama id yok:", j);
    process.exit(3);
  }
  process.stdout.write(id);
} catch (e) {
  console.error("JSON DEGIL:", e.message);
  process.exit(4);
}
NODE
)" || true

if [ -z "${LEAD_ID}" ]; then
  echo "HATA: Lead ID parse edilemedi."
  echo "Muhtemel sebepler:"
  echo " - /leads endpoint'i yok veya farklı path"
  echo " - validation error dönüyor"
  echo " - response JSON değil"
  echo
  echo "Bir sonraki adım için şu dosyaları at:"
  echo "  sed -n '1,200p' src/leads/leads.controller.ts"
  echo "  sed -n '1,260p' src/leads/leads.service.ts"
  exit 1
fi

echo "OK: LEAD_ID=$LEAD_ID"

echo
echo "==> 3) Deal by lead"
curl -i "$BASE/deals/by-lead/$LEAD_ID" || true

echo
echo "==> DONE"
