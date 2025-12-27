#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/deals/deals.service.ts"

echo "==> Backup"
cp "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 - <<'PY'
import re, pathlib

path = pathlib.Path("apps/api/src/deals/deals.service.ts")
txt = path.read_text(encoding="utf-8")

# Tam matchDeal fonksiyonunu yakala
pattern = re.compile(
    r'async\s+matchDeal\s*\([^)]*\)\s*\{[\s\S]*?\n\s*\}',
    re.MULTILINE
)

new_method = """
  async matchDeal(id: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id },
    });

    if (!deal) {
      throw new Error("Deal not found");
    }

    // Idempotency
    if (deal.status === "ASSIGNED") {
      return deal;
    }

    const consultant = await this.prisma.user.findFirst({
      where: { role: "CONSULTANT" },
    });

    if (!consultant) {
      throw new ConflictException("No consultant available");
    }

    return this.prisma.deal.update({
      where: { id },
      data: {
        consultantId: consultant.id,
        status: "ASSIGNED",
      },
    });
  }
"""

if not pattern.search(txt):
    raise SystemExit("❌ matchDeal method not found")

txt = pattern.sub(new_method, txt)
path.write_text(txt, encoding="utf-8")
print("✅ matchDeal replaced cleanly")
PY

echo "==> Build"
cd apps/api
pnpm -s build

echo "✅ DONE"
echo "Next:"
echo "  kill any old server"
echo "  pnpm start:dev"
