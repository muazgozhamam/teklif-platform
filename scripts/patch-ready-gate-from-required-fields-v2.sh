set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"

[[ -f "$FILE" ]] || { echo "❌ File not found: $FILE"; exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"

export FILE

python3 - <<'PY'
import os, re
from pathlib import Path

path = Path(os.environ["FILE"])
txt = path.read_text(encoding="utf-8")

# Ensure prisma import includes DealStatus (merge if possible)
m = re.search(r"import\s*\{\s*([^}]+)\s*\}\s*from\s*['\"]@prisma/client['\"]\s*;\s*", txt)
if m:
    inside = m.group(1)
    if "DealStatus" not in inside:
        new_inside = inside.strip()
        new_inside = (new_inside + ", DealStatus") if new_inside else "DealStatus"
        txt = txt[:m.start(1)] + new_inside + txt[m.end(1):]
else:
    # If no import from @prisma/client, add minimal one (you already have one but safe)
    if "from '@prisma/client'" not in txt and 'from "@prisma/client"' not in txt:
        txt = "import { DealStatus } from '@prisma/client';\n" + txt

# Add helper only if not exists
helper_sig = r"private\s+async\s+markDealReadyForMatching\s*\(\s*dealId\s*:\s*string\s*\)"
if not re.search(helper_sig, txt):
    helper = """
  /**
   * Tek kapı: Wizard tamamlanınca Deal'i READY_FOR_MATCHING'e çeker.
   * Idempotent.
   */
  private async markDealReadyForMatching(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) return;

    if (deal.status !== DealStatus.READY_FOR_MATCHING) {
      await this.prisma.deal.update({
        where: { id: dealId },
        data: { status: DealStatus.READY_FOR_MATCHING },
      });
    }
  }

  /**
   * MVP required fields gate.
   * (Şimdilik sabit; bir sonraki adımda type'a göre dinamik yapacağız.)
   */
  private isDealWizardDone(deal: any) {
    const required = ['city', 'district', 'type', 'rooms'] as const;
    return required.every((k) => Boolean(deal?.[k]));
  }
"""
    m_end = re.search(r"\n}\s*$", txt)
    if not m_end:
        raise SystemExit("❌ Could not find class closing brace to insert helper.")
    txt = txt[:m_end.start()] + helper + txt[m_end.start():]

# Normalize done computation if old inline exists
txt = re.sub(
    r"const\s+done\s*=\s*!!\s*\(\s*updated\.city\s*&&\s*updated\.district\s*&&\s*updated\.type\s*&&\s*updated\.rooms\s*\)\s*;\s*",
    "const done = this.isDealWizardDone(updated);\n",
    txt
)

# Inject markDealReadyForMatching after done (wizardAnswer) if missing
def inject_after_done(block: str) -> str:
    m = re.search(r"const\s+done\s*=\s*this\.isDealWizardDone\(updated\)\s*;\s*", block)
    if not m:
        return block
    window = block[m.end():m.end()+250]
    if "markDealReadyForMatching" in window:
        return block
    inject = "\n    if (done) {\n      await this.markDealReadyForMatching(deal.id);\n    }\n"
    return block[:m.end()] + inject + block[m.end():]

m_wa = re.search(r"async\s+wizardAnswer\s*\([^{]+\)\s*\{", txt)
if m_wa:
    start = m_wa.start()
    i = m_wa.end() - 1
    depth = 0
    end = None
    for j in range(i, len(txt)):
        if txt[j] == "{": depth += 1
        elif txt[j] == "}":
            depth -= 1
            if depth == 0:
                end = j + 1
                break
    if end:
        wa = txt[start:end]
        wa2 = inject_after_done(wa)
        txt = txt[:start] + wa2 + txt[end:]

# Ensure wizardNextQuestion done-block calls helper once
def ensure_ready_in_done_block(src: str) -> str:
    out = src
    for m in list(re.finditer(r"if\s*\(\s*!\s*next\s*\)\s*\{", out)):
        start = m.start()
        i = m.end() - 1
        depth = 0
        end = None
        for j in range(i, len(out)):
            if out[j] == "{": depth += 1
            elif out[j] == "}":
                depth -= 1
                if depth == 0:
                    end = j + 1
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
print("✅ Patch OK (v2): helper + required-fields gate wired")
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
