#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"
[[ -f "$FILE" ]] || { echo "❌ File not found: $FILE"; exit 1; }

# 0) Restore latest backup (safest)
LATEST_BAK="$(ls -1t "$FILE".bak.* 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_BAK}" ]]; then
  cp "$LATEST_BAK" "$FILE"
  echo "✅ Restored latest backup:"
  echo "   $LATEST_BAK -> $FILE"
else
  echo "ℹ️ No backup found. Continuing without restore."
fi

# 1) Fresh backup
TS="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"

python3 - <<'PY'
from pathlib import Path
import re

file_path = Path(__file__).parent.parent / "apps" / "api" / "src" / "leads" / "leads.service.ts"
txt = file_path.read_text(encoding="utf-8")

# Ensure imports exist (DealStatus + BadRequestException used by helpers)
if "DealStatus" not in txt.splitlines()[0:30]:
    # If you already have DealStatus import, skip. Otherwise add it.
    if "from '@prisma/client'" in txt:
        pass
    else:
        # naive: insert after first import line
        lines = txt.splitlines(True)
        for i,l in enumerate(lines):
            if l.startswith("import "):
                lines.insert(i+1, "import { DealStatus } from '@prisma/client';\n")
                txt = "".join(lines)
                break

if "BadRequestException" not in txt:
    # It's already there in your current file; keep safe.
    pass

helpers = """
  private normalizeWizardValue(field: string, raw: string) {
    const v = String(raw ?? '').trim();
    if (!v) throw new BadRequestException('answer boş olamaz');

    if (field === 'city' || field === 'district') {
      return v
        .toLocaleLowerCase('tr-TR')
        .split(' ')
        .filter(Boolean)
        .map(w => w.charAt(0).toLocaleUpperCase('tr-TR') + w.slice(1))
        .join(' ');
    }

    if (field === 'type') {
      const t = v.toUpperCase();
      const allowed = new Set(['SATILIK', 'KIRALIK', 'DUKKAN', 'ARSA']);
      if (!allowed.has(t)) {
        throw new BadRequestException(`Geçersiz type: ${t}. Allowed: SATILIK|KIRALIK|DUKKAN|ARSA`);
      }
      return t;
    }

    if (field === 'rooms') {
      if (!/^\\d+\\+\\d+$/.test(v)) {
        throw new BadRequestException(`Geçersiz rooms: ${v}. Örn: 2+1`);
      }
      return v;
    }

    return v;
  }

  private async markDealReadyForMatching(dealId: string) {
    await this.prisma.deal.update({
      where: { id: dealId },
      data: { status: DealStatus.READY_FOR_MATCHING },
    });
  }
"""

changed = False

# 1) Inject helpers if missing
need_helpers = ("private normalizeWizardValue" not in txt) or ("private async markDealReadyForMatching" not in txt)
if need_helpers:
    # insert before last class closing brace
    idx = txt.rfind("\n}\n")
    if idx == -1:
        idx = txt.rfind("}\n")
    if idx == -1:
        idx = txt.rfind("}")
    if idx == -1:
        raise SystemExit("❌ Could not find closing brace to inject helpers.")
    txt = txt[:idx] + helpers + "\n" + txt[idx:]
    changed = True

# 2) wizardAnswer: normalize value
needle = "const value = String(answer).trim();"
if needle in txt:
    txt = txt.replace(needle, "const value = this.normalizeWizardValue(field, String(answer));", 1)
    changed = True

# 3) wizardAnswer: ensure markDealReadyForMatching after done calc
# First try exact marker
done_marker = "const done = !!(updated.city && updated.district && updated.type && updated.rooms);"
pos = txt.find(done_marker)
inject = "\n\n    if (done) {\n      await this.markDealReadyForMatching(deal.id);\n    }\n"
if pos != -1:
    after = txt[pos+len(done_marker):pos+len(done_marker)+400]
    if "markDealReadyForMatching" not in after:
        txt = txt[:pos+len(done_marker)] + inject + txt[pos+len(done_marker):]
        changed = True
else:
    # soft find
    m = re.search(r"const done\s*=\s*!!\([^\n]*\);\s*", txt)
    if not m:
        raise SystemExit("❌ wizardAnswer içinde done hesaplaması bulunamadı.")
    after = txt[m.end():m.end()+400]
    if "markDealReadyForMatching" not in after:
        txt = txt[:m.end()] + inject + txt[m.end():]
        changed = True

file_path.write_text(txt, encoding="utf-8")
print("✅ Patch applied" if changed else "ℹ️ Nothing to change (already ok)")
PY

echo
echo "==> Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"

echo
echo "Test:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
