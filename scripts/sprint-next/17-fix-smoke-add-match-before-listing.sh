#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/muazgozhamam/Desktop/teklif-platform"
FILE="$ROOT/scripts/sprint-next/04-smoke-deal-listing-runtime.sh"

echo "==> ROOT: $ROOT"
echo "==> Patching: $FILE"

if [ ! -f "$FILE" ]; then
  echo "ERR: file not found: $FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p = Path("/Users/muazgozhamam/Desktop/teklif-platform/scripts/sprint-next/04-smoke-deal-listing-runtime.sh")
txt = p.read_text(encoding="utf-8")

# Zaten eklendiyse dokunma
if "POST /deals/:dealId/match" in txt or "/deals/$DEAL_ID/match" in txt:
    print("OK: match step already exists, no changes.")
    raise SystemExit(0)

needle = "Wizard done."
pos = txt.find(needle)
if pos == -1:
    raise SystemExit("ERR: cannot find 'Wizard done.' line to insert match step after it.")

insert = r'''
sep
echo "==> 3.5) POST /deals/:dealId/match (assign consultant)"
MATCH_URL="$BASE_URL/deals/$DEAL_ID/match"
echo "MATCH URL=$MATCH_URL"
MATCH_RESP_FILE=".tmp/smoke-step35-match.json"
MATCH_CODE="$(curl -sS --show-error --max-time 15 -o "$MATCH_RESP_FILE" -w "%{http_code}" -X POST "$MATCH_URL")" || true
echo "HTTP_CODE=$MATCH_CODE"
echo "--- BODY (first 120 lines) ---"
sed -n '1,120p' "$MATCH_RESP_FILE" 2>/dev/null || true
if [ "$MATCH_CODE" != "200" ] && [ "$MATCH_CODE" != "201" ]; then
  echo "ERR: Match failed (expected 200/201)"
  exit 1
fi
echo "OK: match"
'''

# "Wizard done." satırının hemen altına ekle
line_end = txt.find("\n", pos)
if line_end == -1:
    line_end = len(txt)

txt2 = txt[:line_end+1] + insert + txt[line_end+1:]
p.write_text(txt2, encoding="utf-8")
print("✅ Injected match step before listing upsert")
PY

echo
echo "==> Quick verify"
SMOKE="$ROOT/scripts/sprint-next/04-smoke-deal-listing-runtime.sh"
test -f "$SMOKE" && echo "OK: smoke file exists: $SMOKE" || echo "ERR: smoke file missing: $SMOKE"
rg -n 'POST /deals/:dealId/match|/deals/\$DEAL_ID/match' "$SMOKE" || true

echo
echo "✅ ADIM 17 TAMAM (smoke patch)"
echo "Sonraki: şu komutu çalıştır:"
echo "  cd $ROOT && bash scripts/sprint-next/04-smoke-deal-listing-runtime.sh"
