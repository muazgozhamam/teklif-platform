#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

FILE="apps/api/src/leads/leads.service.ts"

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $ROOT/$FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re
from datetime import datetime

p = Path("apps/api/src/leads/leads.service.ts")
txt = p.read_text(encoding="utf-8")

bak = p.with_suffix(p.suffix + f".bak.wizready.{datetime.now().strftime('%Y%m%d-%H%M%S')}")
bak.write_text(txt, encoding="utf-8")

# 1) wizardNextQuestion: done true dönmeden önce READY_FOR_MATCHING bas
# Hedef: "return { done: true, dealId: deal.id" satırından hemen önce
# "await this.markDealReadyForMatching(deal.id);" ekle (yoksa).
def inject_before_done_return(block: str) -> str:
    # idempotent: zaten varsa tekrar ekleme
    if "markDealReadyForMatching(deal.id)" in block:
        return block
    # return satırını yakala
    m = re.search(r"\n(\s*)return\s*\{\s*done\s*:\s*true\s*,\s*dealId\s*:\s*deal\.id", block)
    if not m:
        return block
    indent = m.group(1)
    ins = f"\n{indent}await this.markDealReadyForMatching(deal.id);\n"
    # insert right before return
    i = m.start()
    return block[:i] + ins + block[i:]

# wizardNextQuestion metod bloğunu bul
m_fn = re.search(r"async\s+wizardNextQuestion\s*\(\s*leadId\s*:\s*string\s*\)\s*\{", txt)
if not m_fn:
    raise SystemExit("❌ Could not find wizardNextQuestion() in leads.service.ts")

# fonksiyon bitişini yaklaşık bul (bir sonraki 'async' veya 'private' veya dosya sonu)
start = m_fn.start()
m_next = re.search(r"\n\s*(async|private)\s+\w+\s*\(", txt[m_fn.end():])
end = (m_fn.end() + m_next.start()) if m_next else len(txt)

before = txt[:start]
fn_block = txt[start:end]
after = txt[end:]

patched_fn = inject_before_done_return(fn_block)
txt2 = before + patched_fn + after

# 2) upsertAnswer içinde done true dönen yer varsa aynı şekilde bas
# upsertAnswer genelde "return { ok: true, done: true, dealId: deal.id" veya benzeri döner.
def inject_in_all_done_returns(s: str) -> str:
    # done true return satırlarından önce mark bas, ama zaten varsa ekleme
    out = s
    # done:true ve dealId:deal.id geçen return'ler
    pattern = re.compile(r"\n(\s*)return\s*\{\s*([^}]*\bdone\s*:\s*true\b[^}]*)\}", re.DOTALL)
    pos = 0
    while True:
        m = pattern.search(out, pos)
        if not m:
            break
        chunk = out[max(0, m.start()-300):m.start()]
        # Yakın çevrede zaten mark var mı?
        if "markDealReadyForMatching(deal.id)" in chunk:
            pos = m.end()
            continue
        indent = m.group(1)
        # deal.id yoksa basma (başka return olabilir)
        if "dealId" in m.group(2) and "deal.id" in m.group(2):
            ins = f"\n{indent}await this.markDealReadyForMatching(deal.id);\n"
            out = out[:m.start()] + ins + out[m.start():]
            pos = m.end() + len(ins)
        else:
            pos = m.end()
    return out

txt3 = inject_in_all_done_returns(txt2)

if txt3 == txt:
    print("ℹ️ No changes applied (already patched or patterns not found).")
else:
    p.write_text(txt3, encoding="utf-8")
    print("✅ Patched: ensure READY_FOR_MATCHING is set when wizard is done.")
    print(f"- Updated: {p}")
    print(f"- Backup : {bak}")
PY

echo "==> Build (optional but recommended)"
( cd apps/api && pnpm -s build )

echo "✅ DONE"
