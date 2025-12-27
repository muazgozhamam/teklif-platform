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

# Step 4: POST satırını yakalayıp yerine debug+timeout’lu blok koyacağız.
# Hem eski (deals/...) hem yeni (listings/deals/...) varyantlarını kapsayalım.
pattern = r'(echo "==> 4\) POST .*?\n)(.*?\n)(?=sep|\n#==>|\necho "==> 5\)|\Z)'
m = re.search(pattern, txt, flags=re.S)
if not m:
    raise SystemExit("ERR: Could not locate Step 4 block in smoke script")

step4_header = m.group(1)

# Yeni Step 4 bloğu: timeout + http_code + body
replacement = step4_header + r'''RESP_FILE=".tmp/smoke-step4-post-listing.json"
rm -f "$RESP_FILE"

URL="$BASE_URL/listings/deals/$DEAL_ID/listing"
echo "POST URL=$URL"

HTTP_CODE="$(curl -sS --show-error --max-time 15 -o "$RESP_FILE" -w "%{http_code}" -X POST "$URL")" || true
echo "HTTP_CODE=$HTTP_CODE"
echo "--- BODY (first 200 lines) ---"
if [ -f "$RESP_FILE" ]; then
  sed -n '1,200p' "$RESP_FILE" || true
else
  echo "(no body file)"
fi

# 200/201 bekliyoruz
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
  echo "ERR: Step 4 failed (expected 200/201)"
  exit 1
fi

LISTING_JSON="$(cat "$RESP_FILE")"
LISTING_ID="$(echo "$LISTING_JSON" | jq -r .id)"
test -n "$LISTING_ID" && test "$LISTING_ID" != "null"
echo "OK: LISTING_ID=$LISTING_ID"

'''

txt2 = txt[:m.start()] + replacement + txt[m.end():]

# Step 5 GET de timeout ekleyelim (varsa)
txt2 = txt2.replace(
    'LISTING2="$(curl -sS "$BASE_URL/listings/deals/$DEAL_ID/listing")"',
    'LISTING2="$(curl -sS --max-time 15 "$BASE_URL/listings/deals/$DEAL_ID/listing")"'
)

if txt2 == txt:
    raise SystemExit("ERR: Patch applied nothing (format differs).")

p.write_text(txt2, encoding="utf-8")
print("✅ Step 4 replaced with timeout+debug block; Step 5 GET timeout added")
PY

echo
echo "==> Quick verify (Step 4 shows curl --max-time)"
rg -n "smoke-step4-post-listing|max-time 15|POST URL=" "$FILE" || true

echo
echo "✅ ADIM 13 TAMAM"
echo "Sonraki: smoke script'i tekrar çalıştır."
