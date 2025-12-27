#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
[ -f "src/deals/deals.service.ts" ] || { echo "HATA: src/deals/deals.service.ts yok."; exit 1; }

echo "==> 1) src/deals/deals.service.ts: getByLeadId yoksa ekle (idempotent)"
node - <<'NODE'
const fs = require("fs");
const p = "src/deals/deals.service.ts";
let t = fs.readFileSync(p, "utf8");

if (t.includes("getByLeadId(") || t.includes("async getByLeadId(")) {
  console.log("==> getByLeadId zaten var. Dokunulmadı.");
  process.exit(0);
}

// NotFoundException import zaten advanceDeal ile eklenmiş olmalı; yine de garanti edelim
t = t.replace(/import\s+\{\s*([^}]+)\s*\}\s+from\s+['"]@nestjs\/common['"];\s*\n/, (m, inner) => {
  const items = inner.split(",").map(s => s.trim()).filter(Boolean);
  if (!items.includes("NotFoundException")) items.push("NotFoundException");
  return `import { ${items.join(", ")} } from '@nestjs/common';\n`;
});

const idx = t.lastIndexOf("}");
if (idx === -1) {
  console.error("HATA: DealsService class kapanışı bulunamadı.");
  process.exit(1);
}

const method = `

  async getByLeadId(leadId: string) {
    // Lead -> Deal ilişkisi projende nasıl kurulduysa ona göre:
    // Varsayım: deal tablosunda leadId alanı var.
    const deal = await this.prisma.deal.findFirst({
      where: { leadId },
      orderBy: { createdAt: 'desc' as any },
    });

    if (!deal) throw new NotFoundException('Deal not found for lead');
    return deal;
  }
`;

t = t.slice(0, idx) + method + "\n" + t.slice(idx);

fs.writeFileSync(p, t, "utf8");
console.log("==> getByLeadId eklendi.");
NODE

echo
echo "==> 2) Build"
pnpm -s build

echo
echo "==> DONE"
echo "Şimdi E2E scriptini çalıştır (terminal BLOKLAMAZ):"
echo "  ./e2e-test-advance-via-api.sh"
