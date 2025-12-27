#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"
[[ -f "$FILE" ]] || { echo "❌ File not found: $FILE"; exit 1; }

# 0) Restore latest backup automatically (safest)
LATEST_BAK="$(ls -1t "$FILE".bak.* 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_BAK}" ]]; then
  cp "$LATEST_BAK" "$FILE"
  echo "✅ Restored latest backup:"
  echo "   $LATEST_BAK -> $FILE"
else
  echo "ℹ️ No backup found. Continuing without restore."
fi

# 1) Make a fresh backup before patch
TS="$(date +%Y%m%d-%H%M%S)"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"

python3 - <<'PY'
from pathlib import Path

path = Path("/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# --- Helpers to inject (string-based; no regex replacement templates) ---
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

# 1) Inject helpers into class (before final closing brace of class)
if "private normalizeWizardValue" not in txt or "private async markDealReadyForMatching" not in txt:
    # Insert before the last "\n}\n" (end of class/file)
    idx = txt.rfind("\n}\n")
    if idx == -1:
        # fallback: last "}"
        idx = txt.rfind("}")
    if idx == -1:
        raise SystemExit("❌ Could not find class/file closing brace to inject helpers.")
    txt = txt[:idx] + helpers + "\n" + txt[idx:]
    changed = True

# 2) Replace value assignment in wizardAnswer (only if exact line exists)
needle = "const value = String(answer).trim();"
if needle in txt:
    txt = txt.replace(needle, "const value = this.normalizeWizardValue(field, String(answer));", 1)
    changed = True

# 3) Insert markDealReadyForMatching after done calculation (only if not already nearby)
done_marker = "const done = !!(updated.city && updated.district && updated.type && updated.rooms);"
pos = txt.find(done_marker)
if pos != -1:
    after = txt[pos + len(done_marker): pos + len(done_marker) + 300]
    if "markDealReadyForMatching" not in after:
        inject = "\n\n    if (done) {\n      await this.markDealReadyForMatching(deal.id);\n    }\n"
        txt = txt[:pos + len(done_marker)] + inject + txt[pos + len(done_marker):]
        changed = True
else:
    # If format differs, do a softer search: line starts with "const done ="
    import re
    m = re.search(r"const done\s*=\s*!!\([^\n]*updated\.[^\n]*\);\s*", txt)
    if m:
        after = txt[m.end():m.end()+300]
        if "markDealReadyForMatching" not in after:
            inject = "\n\n    if (done) {\n      await this.markDealReadyForMatching(deal.id);\n    }\n"
            txt = txt[:m.end()] + inject + txt[m.end():]
            changed = True
    else:
        raise SystemExit("❌ wizardAnswer içinde done hesaplamasını bulamadım. (Dosya formatı farklı)")

path.write_text(txt, encoding="utf-8")
print("✅ Patch applied" if changed else "ℹ️ Nothing to change (already patched)")
PY
