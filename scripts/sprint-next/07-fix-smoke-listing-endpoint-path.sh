#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

FILE="scripts/sprint-next/04-smoke-deal-listing-runtime.sh"
test -f "$FILE" || { echo "ERR: $FILE not found"; exit 1; }

echo "==> Patching: $FILE"

python3 - <<'PY'
from pathlib import Path

p = Path("scripts/sprint-next/04-smoke-deal-listing-runtime.sh")
txt = p.read_text(encoding="utf-8")

# 1) POST /deals/:dealId/listing -> POST /listings/deals/:dealId/listing
txt2 = txt.replace(
    'curl -sS -X POST "$BASE_URL/deals/$DEAL_ID/listing")',
    'curl -sS --max-time 15 -X POST "$BASE_URL/listings/deals/$DEAL_ID/listing")'
)

# 2) GET /deals/:dealId/listing -> GET /listings/deals/:dealId/listing
txt2 = txt2.replace(
    'LISTING2="$(curl -sS "$BASE_URL/deals/$DEAL_ID/listing")"',
    'LISTING2="$(curl -sS --max-time 15 "$BASE_URL/listings/deals/$DEAL_ID/listing")"'
)

# 3) Echo satırlarını da güncelle (bilgilendirme)
txt2 = txt2.replace("POST /deals/:dealId/listing", "POST /listings/deals/:dealId/listing")
txt2 = txt2.replace("GET /deals/:dealId/listing", "GET /listings/deals/:dealId/listing")

if txt2 == txt:
    raise SystemExit("ERR: Patch applied nothing (script already patched or format differs).")

p.write_text(txt2, encoding="utf-8")
print("✅ Patched smoke script listing path + timeouts")
PY

echo
echo "==> Quick verify"
rg -n "listings/deals/\$DEAL_ID/listing" "$FILE" || true

echo
echo "✅ ADIM 7 TAMAM"
echo "Sonraki: smoke script'i tekrar çalıştır."
