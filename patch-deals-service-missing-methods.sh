#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/deals/deals.service.ts"

echo "==> Backup"
cp "$FILE" "$FILE.bak.$(date +%Y%m%d-%H%M%S)"

python3 - <<'PY'
import pathlib, re

path = pathlib.Path("apps/api/src/deals/deals.service.ts")
txt = path.read_text(encoding="utf-8")

insert = """

  // ===== Legacy compatibility methods =====

  async getByLeadId(leadId: string) {
    return this.prisma.deal.findFirst({
      where: { leadId },
      include: {
        lead: true,
        consultant: true,
      },
    });
  }

  async ensureForLead(leadId: string) {
    const existing = await this.prisma.deal.findFirst({
      where: { leadId },
    });

    if (existing) return existing;

    return this.prisma.deal.create({
      data: {
        leadId,
        status: 'READY',
      },
    });
  }

  async ensureStatusReadyForMatching(id: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id } });
    if (!deal) return null;

    if (deal.status === 'READY') return deal;

    return this.prisma.deal.update({
      where: { id },
      data: { status: 'READY' },
    });
  }

  async advanceDeal(id: string, event: string) {
    // Minimal advance: no FSM yet
    return this.prisma.deal.update({
      where: { id },
      data: { status: event },
    });
  }
"""

# insert before last }
idx = txt.rfind("}")
if idx == -1:
    raise SystemExit("Invalid DealsService file")

txt = txt[:idx] + insert + "\n}" + txt[idx+1:]
path.write_text(txt, encoding="utf-8")
print("✅ Missing methods added")
PY

echo "==> Build"
cd apps/api
pnpm -s build
