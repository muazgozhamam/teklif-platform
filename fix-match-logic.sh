#!/usr/bin/env bash
set -euo pipefail

SVC="apps/api/src/deals/deals.service.ts"

echo "==> Backup"
cp "$SVC" "$SVC.bak.$(date +%Y%m%d-%H%M%S)"

python3 - <<'PY'
import re, pathlib

p = pathlib.Path("apps/api/src/deals/deals.service.ts")
txt = p.read_text()

# 1) Idempotency: already assigned
if "already assigned" not in txt:
    txt = re.sub(
        r'async matchDeal\(([^)]*)\)\s*\{',
        r'async matchDeal(\1) {\n    const deal = await this.prisma.deal.findUnique({ where: { id } });\n    if (!deal) throw new Error("Deal not found");\n    if (deal.status === "ASSIGNED") return deal;\n',
        txt
    )

# 2) Force CONSULTANT role only
txt = re.sub(
    r'role:\s*[^,}\n]+',
    'role: "CONSULTANT"',
    txt
)

# 3) If no consultant → throw
if "No consultant available" not in txt:
    txt = re.sub(
        r'const consultant = await this\.prisma\.user\.findFirst\([\s\S]*?\);',
        r'''const consultant = await this.prisma.user.findFirst({
      where: { role: "CONSULTANT" },
    });

    if (!consultant) {
      throw new ConflictException("No consultant available");
    }''',
        txt
    )

p.write_text(txt)
print("✅ matchDeal logic patched")
PY

cd apps/api
pnpm -s build
