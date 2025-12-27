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

# ------------------------------------------------------------
# 1) nextQuestion() içindeki yanlış "deal.id" kullanımını düzelt
#    - if (!next) bloğunda "await this.markDealReadyForMatching(deal.id);" varsa
#      onu: const d = await this.dealsService.ensureForLead(id); await this.markDealReadyForMatching(d.id);
# ------------------------------------------------------------

# nextQuestion method block slice
m = re.search(r"async\s+nextQuestion\s*\(\s*id\s*:\s*string\s*\)\s*\{", txt)
if m:
    start = m.start()
    i = m.end() - 1
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
        block = txt[start:end]

        # find if (!next) { ... } block
        m2 = re.search(r"if\s*\(\s*!\s*next\s*\)\s*\{", block)
        if m2:
            bstart = m2.start()
            k = m2.end() - 1
            d2 = 0
            bend = None
            for t in range(k, len(block)):
                if block[t] == "{": d2 += 1
                elif block[t] == "}":
                    d2 -= 1
                    if d2 == 0:
                        bend = t + 1
                        break
            if bend:
                done_block = block[bstart:bend]

                # Replace wrong line if present
                wrong = r"await\s+this\.markDealReadyForMatching\s*\(\s*deal\.id\s*\)\s*;\s*"
                if re.search(wrong, done_block):
                    replacement = (
                        "const d = await this.dealsService.ensureForLead(id);\n"
                        "      await this.markDealReadyForMatching(d.id);\n      "
                    )
                    done_block2 = re.sub(wrong, replacement, done_block, count=1)
                    block2 = block[:bstart] + done_block2 + block[bend:]
                    txt = txt[:start] + block2 + txt[end:]
                else:
                    # If not present, do nothing
                    pass

# ------------------------------------------------------------
# 2) isDealWizardDone helper'ı class içine garanti ekle
# ------------------------------------------------------------
has_is_done = re.search(r"\bisDealWizardDone\s*\(", txt) is not None
has_is_done_impl = re.search(r"private\s+isDealWizardDone\s*\(", txt) is not None

if has_is_done and not has_is_done_impl:
    # insert method before final class closing brace
    class_m = re.search(r"export\s+class\s+LeadsService\s*\{", txt)
    if not class_m:
        raise SystemExit("❌ LeadsService class not found")

    # find the matching closing brace of class (last '}' of class)
    start = class_m.end() - 1
    depth = 0
    end = None
    for j in range(start, len(txt)):
        if txt[j] == "{": depth += 1
        elif txt[j] == "}":
            depth -= 1
            if depth == 0:
                end = j
                break
    if end is None:
        raise SystemExit("❌ Could not find class end brace")

    method = """
  /**
   * MVP required-fields gate (şimdilik sabit).
   * Sonraki adım: type'a göre dinamik required list.
   */
  private isDealWizardDone(deal: any) {
    const required = ['city', 'district', 'type', 'rooms'] as const;
    return required.every((k) => Boolean(deal?.[k]));
  }

"""
    txt = txt[:end] + method + txt[end:]

path.write_text(txt, encoding="utf-8")
print("✅ Fix applied: nextQuestion(deal.id) + isDealWizardDone ensured")
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
