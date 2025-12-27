#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/muazgozhamam/Desktop/teklif-platform"
F="$ROOT/scripts/sprint-next/17-fix-smoke-add-match-before-listing.sh"

echo "==> Fixing: $F"
test -f "$F"

python3 - <<'PY'
from pathlib import Path
p = Path("/Users/muazgozhamam/Desktop/teklif-platform/scripts/sprint-next/17-fix-smoke-add-match-before-listing.sh")
txt = p.read_text(encoding="utf-8")

old = r'rg -n "POST /deals/:dealId/match|/deals/\\$DEAL_ID/match" "$FILE" || true'
if old not in txt:
    # alternatif olarak gevşek yakala ve değiştir
    import re
    txt2 = re.sub(r'rg -n "POST /deals/:dealId/match\|/deals/\\\\\$DEAL_ID/match" "\$FILE" \|\| true',
                 r"rg -n 'POST /deals/:dealId/match|/deals/\$DEAL_ID/match' \"$FILE\" || true",
                 txt)
    if txt2 == txt:
        raise SystemExit("ERR: target rg line not found; file format differs.")
    txt = txt2
else:
    txt = txt.replace(old, r"rg -n 'POST /deals/:dealId/match|/deals/\$DEAL_ID/match' \"$FILE\" || true")

p.write_text(txt, encoding="utf-8")
print("✅ Patched patch17: rg now uses single quotes to avoid $DEAL_ID expansion")
PY

echo "✅ DONE"
