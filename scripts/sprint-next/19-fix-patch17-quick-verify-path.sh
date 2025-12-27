#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT/scripts/sprint-next/17-fix-smoke-add-match-before-listing.sh"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("scripts/sprint-next/17-fix-smoke-add-match-before-listing.sh")
txt = p.read_text(encoding="utf-8")

# 1) FILE değişkenini mutlaka doğru ve quotesuz yap
# Mevcut: FILE=".../04-smoke...sh" veya FILE='...'
txt = re.sub(
    r'^\s*FILE=.*$',
    'FILE="$ROOT/scripts/sprint-next/04-smoke-deal-listing-runtime.sh"',
    txt,
    flags=re.M
)

# 2) Quick verify rg satırını güvenli hale getir (tek tırnak pattern, double tırnak file)
# Hedef satır: rg -n 'POST /deals/:dealId/match|/deals/\$DEAL_ID/match' "$FILE" || true
txt2 = re.sub(
    r'^\s*rg\s+-n\s+.*\$FILE.*$',
    r"rg -n 'POST /deals/:dealId/match|/deals/\$DEAL_ID/match' \"$FILE\" || true",
    txt,
    flags=re.M
)

# Eğer rg satırı yoksa ekle (Quick verify bloğu sonrasına)
if txt2 == txt and "==> Quick verify" in txt:
    lines = txt.splitlines(True)
    out = []
    inserted = False
    for i, line in enumerate(lines):
        out.append(line)
        if (not inserted) and ("==> Quick verify" in line):
            # bir sonraki satıra rg ekle
            out.append("rg -n 'POST /deals/:dealId/match|/deals/\\$DEAL_ID/match' \"$FILE\" || true\n")
            inserted = True
    txt2 = "".join(out)

p.write_text(txt2, encoding="utf-8")
print("✅ patch17 Quick verify: FILE normalized + rg fixed")
PY

echo
echo "==> Smoke file exists?"
test -f "$ROOT/scripts/sprint-next/04-smoke-deal-listing-runtime.sh" && echo "OK: smoke file present" || (echo "ERR: smoke file missing" && exit 1)

echo
echo "==> Run patch17 (should not rg-IO-error now)"
bash "$FILE"

echo
echo "✅ DONE"
