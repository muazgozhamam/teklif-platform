#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/deals/deals.service.ts" ] || { echo "HATA: src/deals/deals.service.ts yok."; exit 1; }
[ -f "src/deals/deals.engine.ts" ] || { echo "HATA: src/deals/deals.engine.ts yok."; exit 1; }

echo "==> 1) src/deals/deals.service.ts: advanceDeal yoksa ekle (idempotent)"
node - <<'NODE'
const fs = require("fs");
const p = "src/deals/deals.service.ts";
let t = fs.readFileSync(p, "utf8");

if (t.includes("async advanceDeal(")) {
  console.log("==> advanceDeal zaten var. Dokunulmadı.");
  process.exit(0);
}

// DealEvent/nextStatus importlarını garanti et
if (!t.includes("from './deals.engine'")) {
  // class importlarının altına ekle
  t = t.replace(/(from\s+['"]@nestjs\/common['"];\s*\n)/m, `$1import { DealEvent, nextStatus } from './deals.engine';\n`);
} else {
  // var ama eksik olabilir
  t = t.replace(/import\s+\{\s*([^}]+)\s*\}\s+from\s+['"]\.\/deals\.engine['"];\s*\n/, (m, inner) => {
    const items = inner.split(",").map(s => s.trim()).filter(Boolean);
    for (const need of ["DealEvent","nextStatus"]) if (!items.includes(need)) items.push(need);
    return `import { ${items.join(", ")} } from './deals.engine';\n`;
  });
}

// NotFound/BadRequest importları yoksa ekle
t = t.replace(/import\s+\{\s*([^}]+)\s*\}\s+from\s+['"]@nestjs\/common['"];\s*\n/, (m, inner) => {
  const items = inner.split(",").map(s => s.trim()).filter(Boolean);
  for (const need of ["NotFoundException","BadRequestException"]) if (!items.includes(need)) items.push(need);
  return `import { ${items.join(", ")} } from '@nestjs/common';\n`;
});

// advanceDeal methodunu class içine ekle (son } öncesi)
const idx = t.lastIndexOf("}");
if (idx === -1) {
  console.error("HATA: DealsService class kapanışı bulunamadı.");
  process.exit(1);
}

const method = `

  async advanceDeal(dealId: string, event: DealEvent) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const current = deal.status as any;
    const next = nextStatus(current, event);

    if (next === current) {
      throw new BadRequestException(\`No transition: \${current} + \${event}\`);
    }

    const now = new Date();
    const patch: any = { status: next, statusChangedAt: now };

    if (next === 'QUALIFIED') patch.qualifiedAt = now;
    if (next === 'ACCEPTED') patch.acceptedAt = now;
    if (next === 'REJECTED') patch.rejectedAt = now;
    if (next === 'EXPIRED') patch.expiresAt = now;

    return this.prisma.deal.update({ where: { id: dealId }, data: patch });
  }
`;

t = t.slice(0, idx) + method + "\n" + t.slice(idx);

fs.writeFileSync(p, t, "utf8");
console.log("==> advanceDeal eklendi.");
NODE

echo
echo "==> 2) Build"
pnpm -s build

echo
echo "==> DONE"
echo "Şimdi bir önceki scripti tekrar çalıştıracağız (restart + verify)."
