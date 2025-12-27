#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

FILE="scripts/sprint-next/04-smoke-deal-listing-runtime.sh"
test -f "$FILE" || { echo "ERR: $FILE not found"; exit 1; }

echo "==> Patching: $FILE"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("scripts/sprint-next/04-smoke-deal-listing-runtime.sh")
txt = p.read_text(encoding="utf-8")

# 1) Soru çekme: GET /wizard/$LEAD_ID  -> POST /leads/$LEAD_ID/wizard/next-question
txt2 = txt.replace(
    'Q="$(curl -sS "$BASE_URL/wizard/$LEAD_ID")"',
    'Q="$(curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"'
)

# 2) Answer: POST /wizard/$LEAD_ID/answer -> POST /leads/$LEAD_ID/wizard/answer
txt2 = txt2.replace(
    'curl -sS -X POST "$BASE_URL/wizard/$LEAD_ID/answer" \\',
    'curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \\'
)

# 3) Takılmayı önlemek için curl timeout ekle (sadece wizard çağrıları için)
txt2 = txt2.replace(
    'curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"',
    'curl -sS --max-time 10 -X POST "$BASE_URL/leads/$LEAD_ID/wizard/next-question")"'
)
txt2 = txt2.replace(
    'curl -sS -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \\',
    'curl -sS --max-time 10 -X POST "$BASE_URL/leads/$LEAD_ID/wizard/answer" \\'
)

if txt2 == txt:
    raise SystemExit("ERR: Patch applied nothing (script already patched or format differs).")

p.write_text(txt2, encoding="utf-8")
print("✅ Patched smoke script to use /leads/:id/wizard/* endpoints + curl timeouts")
PY

echo
echo "==> Quick verify (grep)"
rg -n "wizard/next-question|wizard/answer" "$FILE" || true

echo
echo "✅ ADIM 6 TAMAM"
echo "Sonraki: aynı smoke script'i tekrar çalıştır."
