#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT/apps/api"
FILE="$API_DIR/src/leads/leads.service.ts"

echo "ROOT=$ROOT"
echo "API_DIR=$API_DIR"
echo "FILE=$FILE"
echo

[[ -f "$FILE" ]] || { echo "❌ Dosya yok: $FILE"; exit 1; }

TS="$(date +"%Y%m%d-%H%M%S")"
cp "$FILE" "$FILE.bak.$TS"
echo "✅ Backup: $FILE.bak.$TS"

python3 - <<'PY'
from pathlib import Path
import re

path = Path("apps/api/src/leads/leads.service.ts")
txt = path.read_text(encoding="utf-8")

# 1) wizardAnswer içinde "const done = !!(updated.city && ...)" satırını bul
pat = r"const done\s*=\s*!!\(\s*updated\.city\s*&&\s*updated\.district\s*&&\s*updated\.type\s*&&\s*updated\.rooms\s*\)\s*;\s*"
m = re.search(pat, txt)
if not m:
    raise SystemExit("❌ wizardAnswer içinde done hesabı bulunamadı. (format beklenmedik)")

# 2) Daha önce patch yapılmış mı kontrol et
if "READY_FOR_MATCHING_ON_DONE" in txt:
    print("ℹ️ Patch zaten uygulanmış (skip).")
    raise SystemExit(0)

inject = """
const done = !!(updated.city && updated.district && updated.type && updated.rooms);

const dealFinal = done
  ? await this.prisma.deal.update({
      where: { id: deal.id },
      data: { status: DealStatus.READY_FOR_MATCHING },
      include: { lead: true, consultant: true },
    })
  : updated;
// READY_FOR_MATCHING_ON_DONE
"""

# done satırını komple inject ile değiştir
txt2 = txt[:m.start()] + inject + txt[m.end():]

# 3) Aşağıda return bloğunda "deal: updated" geçiyorsa "deal: dealFinal" yap
txt2 = txt2.replace("deal: updated,", "deal: dealFinal,")

path.write_text(txt2, encoding="utf-8")
print("✅ Patch OK: wizardAnswer done=true => status READY_FOR_MATCHING (aynı response'da dealFinal döner)")
PY

echo
echo "==> Prisma generate + build (apps/api)"
cd "$API_DIR"
pnpm -s prisma generate --schema prisma/schema.prisma
pnpm -s build
echo "✅ build OK"

echo
echo "Sonraki test:"
echo "  cd $ROOT"
echo "  kill \$(cat /tmp/teklif-api-dev.pid) 2>/dev/null || true"
echo "  ./dev-start-and-e2e.sh"
