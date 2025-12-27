#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"

[[ -f "$FILE" ]] || { echo "❌ File not found: $FILE"; exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"

python3 - <<PY
from pathlib import Path
import re

path = Path(r"$FILE")
txt = path.read_text(encoding="utf-8")

# 1) Helpers ekle (yoksa)
if "private normalizeWizardValue" not in txt:
    helpers = r"""
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
        throw new BadRequestException(\`Geçersiz type: \${t}. Allowed: SATILIK|KIRALIK|DUKKAN|ARSA\`);
      }
      return t;
    }

    if (field === 'rooms') {
      if (!/^\\d+\\+\\d+$/.test(v)) {
        throw new BadRequestException(\`Geçersiz rooms: \${v}. Örn: 2+1\`);
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
    txt = re.sub(r"\n}\s*$", helpers + "\n}\n", txt, flags=re.S)

# 2) wizardAnswer içinde value normalize et
txt, n1 = re.subn(
    r"const value\s*=\s*String\(answer\)\.trim\(\)\s*;\s*",
    "const value = this.normalizeWizardValue(field, String(answer));\n\n    ",
    txt,
    flags=re.M
)

# 3) wizardAnswer içinde done hesaplandıktan sonra (return'den önce) markReady çağır
# Hedef satır: const done = !!(updated.city && updated.district && updated.type && updated.rooms);
m = re.search(r"const done\s*=\s*!!\([^\n]*updated\.[^\n]*\);\s*", txt)
if not m:
    raise SystemExit("❌ wizardAnswer içinde `const done = ... (updated...)` bulunamadı. (Format farklı olabilir)")

after = txt[m.end():m.end()+400]
if "markDealReadyForMatching" not in after:
    inject = "\n\n    if (done) {\n      await this.markDealReadyForMatching(deal.id);\n    }\n\n"
    txt = txt[:m.end()] + inject + txt[m.end():]

path.write_text(txt, encoding="utf-8")
print(f"✅ Patch OK (normalize+ready). replaced_value_line={n1}")
PY

echo "==> Build (apps/api)"
cd "$API_DIR"
pnpm -s build
echo "✅ build OK"

echo
echo "Sonraki test:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
