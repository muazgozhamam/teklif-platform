#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/deals/matching.service.ts"

echo "==> Patch: $FILE"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/deals/matching.service.ts")
txt = p.read_text(encoding="utf-8")

# 1) loadByConsultant() fonksiyonunu tamamen güvenli versiyonla değiştir
# groupBy + _count yerine consultants listesine göre count() yapacağız.
pattern = r"private async loadByConsultant\(\): Promise<Map<string, number>> \{[\s\S]*?\n\s*\}\n"
replacement = """private async loadByConsultant(consultantIds: string[]): Promise<Map<string, number>> {
    // Şemanda ASKING yok; bu yüzden sadece kesin statuslar:
    const ACTIVE_STATUSES = ['OPEN', 'READY_FOR_MATCHING', 'ASSIGNED'] as const;

    const m = new Map<string, number>();
    for (const cid of consultantIds) {
      const c = await this.prisma.deal.count({
        where: {
          consultantId: cid,
          status: { in: [...ACTIVE_STATUSES] as any },
        },
      });
      m.set(cid, c);
    }
    return m;
  }
"""
txt2, n = re.subn(pattern, replacement, txt, count=1)
if n == 0:
    raise SystemExit("❌ loadByConsultant() bloğu bulunamadı; dosya beklenenden farklı.")

txt = txt2

# 2) pickConsultantForDeal içinde loadByConsultant() çağrısını yeni imzaya uydur
txt = txt.replace("const loadMap = await this.loadByConsultant();",
                  "const loadMap = await this.loadByConsultant(consultants.map(c => c.id));")

p.write_text(txt, encoding="utf-8")
print("✅ patched:", p)
PY

echo "✅ DONE."
echo "Şimdi API build tekrar dene (aynı terminalde watch zaten derleyecek)."
