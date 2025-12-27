#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH17="$ROOT/scripts/sprint-next/17-fix-smoke-add-match-before-listing.sh"
SMOKE="$ROOT/scripts/sprint-next/04-smoke-deal-listing-runtime.sh"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("scripts/sprint-next/17-fix-smoke-add-match-before-listing.sh")
txt = p.read_text(encoding="utf-8")

# 1) FILE satırını kesin olarak temizle (literal quote gömülmesini yok et)
# Ne olursa olsun tek bir doğru satıra indiriyoruz.
txt = re.sub(
    r'^\s*FILE=.*$',
    'FILE="$ROOT/scripts/sprint-next/04-smoke-deal-listing-runtime.sh"',
    txt,
    flags=re.M
)

# 2) Quick verify kısmını FILE'dan bağımsız hale getir:
#    rg komutunu direkt $ROOT/.../04-smoke... üzerinden çalıştır.
# Mevcut rg satır(lar)ını silip yerine güvenli blok koyacağız.
lines = txt.splitlines(True)
out = []
i = 0
while i < len(lines):
    line = lines[i]
    out.append(line)

    if "==> Quick verify" in line:
        # Quick verify'den sonraki rg satırlarını temizle (birkaç satır olabilir)
        j = i + 1
        while j < len(lines) and re.search(r'^\s*rg\s+-n\s+', lines[j]):
            j += 1

        # Güvenli verify bloğunu enjekte et
        out.append('SMOKE="$ROOT/scripts/sprint-next/04-smoke-deal-listing-runtime.sh"\n')
        out.append('test -f "$SMOKE" && echo "OK: smoke file exists: $SMOKE" || echo "ERR: smoke file missing: $SMOKE"\n')
        out.append("rg -n 'POST /deals/:dealId/match|/deals/\\$DEAL_ID/match' \"$SMOKE\" || true\n")

        # i'yi rg satırlarından sonraya taşı
        i = j
        continue

    i += 1

txt2 = "".join(out)
p.write_text(txt2, encoding="utf-8")
print("✅ patch17 hardened: FILE cleaned + quick verify uses $ROOT path (no embedded quotes)")
PY

echo
echo "==> Sanity: print patch17 FILE line + quick verify lines"
grep -nE '^(FILE=|SMOKE=|rg -n )' "$PATCH17" | sed -n '1,160p'

echo
echo "==> Run patch17 (should not rg IO error now)"
bash "$PATCH17"

echo
echo "✅ DONE"
