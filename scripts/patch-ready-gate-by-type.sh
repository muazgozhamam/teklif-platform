#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"

ts="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$ts"
echo "✅ Backup: $FILE.bak.$ts"

python3 - <<PY
from pathlib import Path
import re

path = Path("$FILE")
txt = path.read_text(encoding="utf-8")

# 1) Ensure helper methods exist once: normalizeType, required-fields, isDealWizardDone
def ensure_block(name: str, block: str):
    global txt
    if name in txt:
        return
    # insert before last class closing brace
    i = txt.rfind("}")
    if i == -1:
        raise SystemExit("❌ Could not find class closing brace in file.")
    txt = txt[:i] + "\\n\\n" + block.strip() + "\\n\\n" + txt[i:]

helpers = r"""
  private normalizeType(v?: string | null) {
    return String(v ?? '')
      .trim()
      .replace(/\s+/g, ' ')
      .toUpperCase();
  }

  /**
   * Deal "type" değerine göre hangi alanlar zorunlu?
   * Not: Şu an type string. İleride enum / propertyType ile netleştireceğiz.
   */
  private requiredFieldsForDeal(typeRaw?: string | null): Array<'city'|'district'|'type'|'rooms'> {
    const t = this.normalizeType(typeRaw);

    // rooms zorunlu OLMAYAN tipler (arsa/tarla vb.)
    const noRooms = new Set([
      'ARSA','TARLA','BAHCE','BAHÇE','KAPALI ARSA','IMARLI ARSA','İMARLI ARSA',
      'DÜKKAN','DUKKAN','İŞYERİ','ISYERI','OFIS','OFİS','DEPO'
    ]);

    if (noRooms.has(t)) {
      return ['city','district','type'];
    }

    // default: konut gibi düşün -> rooms zorunlu
    return ['city','district','type','rooms'];
  }

  private isDealWizardDone(deal: any): boolean {
    const req = this.requiredFieldsForDeal(deal?.type);
    return req.every((k) => {
      const v = (deal as any)[k];
      return v !== null && v !== undefined && String(v).trim().length > 0;
    });
  }

  private async markDealReadyForMatching(dealId: string) {
    // idempotent
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) return;

    if (deal.status === 'READY_FOR_MATCHING' || deal.status === 'ASSIGNED' || deal.status === 'WON' || deal.status === 'LOST') {
      return;
    }

    // gate: required fields dolu mu?
    if (!this.isDealWizardDone(deal)) return;

    await this.prisma.deal.update({
      where: { id: dealId },
      data: { status: DealStatus.READY_FOR_MATCHING },
    });
  }
"""

ensure_block("private normalizeType", helpers)

# 2) wizardAnswer içinde done hesabını isDealWizardDone(updated) ile değiştir
#    Ayrıca type alanı dolduruluyorsa normalize et.
#    (mevcut: const done = !!(updated.city && ...))
# Replace the first occurrence robustly.
txt2 = txt

# If data[field]=value block exists, normalize when field == 'type'
pattern_assign = re.compile(r"(const data: any = \{\};\s*data\[field\] = value;)", re.M)
m = pattern_assign.search(txt2)
if m:
    inject = """const data: any = {};
    // normalize
    data[field] = (field === 'type') ? this.normalizeType(value) : value;"""
    txt2 = txt2[:m.start()] + inject + txt2[m.end():]

# Replace done computation
pattern_done = re.compile(r"const done\s*=\s*!!\s*\(\s*updated\.city\s*&&\s*updated\.district\s*&&\s*updated\.type\s*&&\s*updated\.rooms\s*\)\s*;", re.M)
txt2, n = pattern_done.subn("const done = this.isDealWizardDone(updated);", txt2, count=1)

# If not found, try a looser pattern: const done = !!(...); in wizardAnswer block
if n == 0:
    pattern_loose = re.compile(r"const done\s*=\s*!!\s*\([^\)]*\)\s*;", re.M)
    txt2, n2 = pattern_loose.subn("const done = this.isDealWizardDone(updated);", txt2, count=1)

txt = txt2

# 3) Ensure: if (done) await this.markDealReadyForMatching(deal.id); exists inside wizardAnswer after done line
# We'll insert right after "const done = this.isDealWizardDone(updated);"
anchor = "const done = this.isDealWizardDone(updated);"
idx = txt.find(anchor)
if idx == -1:
    raise SystemExit("❌ Could not find done anchor in wizardAnswer after patch.")
window = txt[idx: idx + 250]
if "markDealReadyForMatching" not in window:
    insert = anchor + "\\n\\n    if (done) {\\n      await this.markDealReadyForMatching(deal.id);\\n    }\\n"
    txt = txt[:idx] + insert + txt[idx+len(anchor):]

# 4) Remove duplicate markDealReadyForMatching implementations if any (keep first)
pat = re.compile(r"\\n\\s*private async markDealReadyForMatching\\(dealId: string\\)\\s*\\{", re.M)
matches = list(pat.finditer(txt))
if len(matches) > 1:
    # remove later ones by cutting blocks via brace matching
    keep_start = matches[0].start()
    # find end of first block
    def find_block_end(s, start_idx):
        i = s.find("{", start_idx)
        if i == -1: return -1
        depth = 0
        for j in range(i, len(s)):
            if s[j] == "{": depth += 1
            elif s[j] == "}":
                depth -= 1
                if depth == 0:
                    return j+1
        return -1

    first_end = find_block_end(txt, matches[0].start())
    out = txt[:first_end]
    rest = txt[first_end:]
    # drop any subsequent blocks
    for m in matches[1:]:
        # recompute in rest space by searching again
        pass

    # simpler: repeatedly remove the 2nd occurrence block
    while True:
        ms = list(pat.finditer(txt))
        if len(ms) <= 1: break
        start = ms[1].start()
        end = find_block_end(txt, start)
        if end == -1:
            raise SystemExit("❌ Could not remove duplicate helper block (brace mismatch).")
        txt = txt[:start] + "\\n" + txt[end:]

path.write_text(txt, encoding="utf-8")
print("✅ Patch OK: READY gate by type + wizardAnswer wired")
PY

echo
echo "==> Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"

echo
echo "==> Test"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
