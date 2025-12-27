set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"

if [[ ! -f "$FILE" ]]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"

python3 - <<'PY'
from pathlib import Path
import re

path = Path(r"""'"$FILE"'""")
txt = path.read_text(encoding="utf-8")

# 1) Ensure DealStatus import exists (needed by helper).
#    If already present, keep; if not, add at top.
if "DealStatus" not in txt or "from '@prisma/client'" not in txt:
    # try to merge into existing prisma import
    m = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*['\"]@prisma/client['\"]\s*;\s*", txt)
    if m:
        inside = m.group(1)
        if "DealStatus" not in inside:
            new_inside = inside.strip()
            if new_inside.endswith(","):
                new_inside += " DealStatus"
            else:
                new_inside += ", DealStatus"
            txt = txt[:m.start(1)] + new_inside + txt[m.end(1):]
    else:
        txt = "import { DealStatus } from '@prisma/client';\n" + txt

# 2) Add helper once (if not exists)
helper_sig = r"private\s+async\s+markDealReadyForMatching\s*\(\s*dealId\s*:\s*string\s*\)"
if not re.search(helper_sig, txt):
    helper = """
  /**
   * Tek kapı: Wizard tamamlanınca Deal'i READY_FOR_MATCHING'e çeker.
   * Idempotent: zaten READY/ASSIGNED vb ise tekrar update etmeye gerek yok.
   */
  private async markDealReadyForMatching(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) return;

    // Sadece OPEN/IN_PROGRESS gibi durumlarda READY'e çek.
    // (İstersen burada daha katı bir state machine uygularız.)
    if (deal.status !== DealStatus.READY_FOR_MATCHING) {
      await this.prisma.deal.update({
        where: { id: dealId },
        data: { status: DealStatus.READY_FOR_MATCHING },
      });
    }
  }

  /**
   * MVP required fields gate.
   * Wizard soruları ileride artsa bile READY gate’i buradan kontrol ederiz.
   */
  private isDealWizardDone(deal: any) {
    const required = ['city', 'district', 'type', 'rooms'] as const;
    return required.every((k) => Boolean(deal?.[k]));
  }
"""
    # Insert before class closing brace (last "}" of class).
    # Safer: insert before final "\n}\n" or last "}\n" in file.
    m_end = re.search(r"\n}\s*$", txt)
    if not m_end:
        raise SystemExit("❌ Could not find class closing brace to insert helper.")
    txt = txt[:m_end.start()] + helper + txt[m_end.start():]

# 3) Normalize "done" computation in wizardAnswer:
#    Replace: const done = !!(updated.city && updated.district && updated.type && updated.rooms);
#    With:    const done = this.isDealWizardDone(updated);
txt2, n = re.subn(
    r"const\s+done\s*=\s*!!\s*\(\s*updated\.city\s*&&\s*updated\.district\s*&&\s*updated\.type\s*&&\s*updated\.rooms\s*\)\s*;\s*",
    "const done = this.isDealWizardDone(updated);\n",
    txt
)
txt = txt2

# 4) After "const done = ..." inside wizardAnswer, ensure we call markDealReadyForMatching once.
#    Inject only if not already nearby.
def inject_after_done(block: str) -> str:
    m = re.search(r"const\s+done\s*=\s*this\.isDealWizardDone\(updated\)\s*;\s*", block)
    if not m:
        return block
    window = block[m.end():m.end()+250]
    if "markDealReadyForMatching" in window:
        return block
    inject = "\n    if (done) {\n      await this.markDealReadyForMatching(deal.id);\n    }\n"
    return block[:m.end()] + inject + block[m.end():]

# Find wizardAnswer method block (best-effort)
m_wa = re.search(r"async\s+wizardAnswer\s*\([^{]+\)\s*\{", txt)
if m_wa:
    # crude block slicing by counting braces
    start = m_wa.start()
    i = m_wa.end()-1
    depth = 0
    end = None
    for j in range(i, len(txt)):
        if txt[j] == "{":
            depth += 1
        elif txt[j] == "}":
            depth -= 1
            if depth == 0:
                end = j+1
                break
    if end:
        wa_block = txt[start:end]
        wa_new = inject_after_done(wa_block)
        txt = txt[:start] + wa_new + txt[end:]

# 5) In wizardNextQuestion: when next == null (done), ensure markDealReadyForMatching is called once.
#    We look for "if (!next) {" block and before "return { done: true"
def ensure_ready_in_done_block(txt: str) -> str:
    # Find "if (!next)" blocks
    out = txt
    for m in list(re.finditer(r"if\s*\(\s*!\s*next\s*\)\s*\{", out)):
        # locate block
        start = m.start()
        i = m.end()-1
        depth = 0
        end = None
        for j in range(i, len(out)):
            if out[j] == "{":
                depth += 1
            elif out[j] == "}":
                depth -= 1
                if depth == 0:
                    end = j+1
                    break
        if not end:
            continue
        block = out[start:end]
        if "return { done: true" in block and "markDealReadyForMatching" not in block:
            block = re.sub(
                r"(return\s*\{\s*done\s*:\s*true[^;]*;\s*)",
                r"await this.markDealReadyForMatching(deal.id);\n      \1",
                block,
                count=1
            )
            out = out[:start] + block + out[end:]
            break
    return out

txt = ensure_ready_in_done_block(txt)

path.write_text(txt, encoding="utf-8")
print("✅ Patch complete: required-fields gate + single READY helper")
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
