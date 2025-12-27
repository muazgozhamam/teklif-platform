#!/usr/bin/env bash
set -euo pipefail

# FAIL-FAST
[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin. cd ~/Desktop/teklif-platform/apps/api"; exit 1; }
[ -f "prisma/schema.prisma" ] || { echo "HATA: prisma/schema.prisma bulunamadı."; exit 1; }

echo "==> 1) Prisma schema: DealStatus enum + Deal.status alanı ekleniyor (idempotent)"

node - <<'NODE'
const fs = require("fs");
const p = "prisma/schema.prisma";
let s = fs.readFileSync(p, "utf8");

// 1) enum DealStatus yoksa ekle (dosyanın sonuna)
if (!/\benum\s+DealStatus\b/.test(s)) {
  s += `

enum DealStatus {
  DRAFT
  QUALIFIED
  OFFER_SENT
  NEGOTIATING
  ACCEPTED
  REJECTED
  EXPIRED
}
`;
}

// 2) model Deal içine status alanı ekle
const dealModelMatch = s.match(/model\s+Deal\s*\{[\s\S]*?\n\}/m);
if (!dealModelMatch) {
  console.error("HATA: schema.prisma içinde model Deal bulunamadı. (Deal çekirdeği farklı isimde olabilir.)");
  process.exit(1);
}

let dealBlock = dealModelMatch[0];

// status alanı yoksa ekle
if (!/\bstatus\s+DealStatus\b/.test(dealBlock)) {
  // Ekleme stratejisi: model bloğunun sonuna (kapanıştan hemen önce) ekle
  // default DRAFT, indeks, timestamps
  const insertion = `
  status           DealStatus @default(DRAFT)
  statusChangedAt  DateTime? 
  qualifiedAt      DateTime?
  acceptedAt       DateTime?
  rejectedAt       DateTime?
  expiresAt        DateTime?

  @@index([status])
`;
  dealBlock = dealBlock.replace(/\n\}\s*$/m, `${insertion}\n}`);
  s = s.replace(dealModelMatch[0], dealBlock);
}

fs.writeFileSync(p, s, "utf8");
console.log("==> schema.prisma patched.");
NODE

echo "==> 2) Deal engine dosyaları (service + controller) hazırlanıyor"

# deals dizini
mkdir -p src/deals

# 2A) deals.engine.ts (yeni/overwrite güvenli)
cat > src/deals/deals.engine.ts <<'TS'
export type DealStatus =
  | 'DRAFT'
  | 'QUALIFIED'
  | 'OFFER_SENT'
  | 'NEGOTIATING'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'EXPIRED';

export type DealEvent =
  | 'QUESTIONS_COMPLETED'
  | 'BROKER_ASSIGNED'
  | 'OFFER_SENT'
  | 'OFFER_ACCEPTED'
  | 'OFFER_REJECTED'
  | 'EXPIRE'
  | 'REOPEN_NEGOTIATION';

export function nextStatus(current: DealStatus, event: DealEvent): DealStatus {
  // Minimal, deterministic transition map
  switch (event) {
    case 'QUESTIONS_COMPLETED':
      return current === 'DRAFT' ? 'QUALIFIED' : current;

    case 'BROKER_ASSIGNED':
      // broker atanması teklif sürecine hazırlık sayılır
      return current === 'QUALIFIED' ? 'OFFER_SENT' : current;

    case 'OFFER_SENT':
      return current === 'QUALIFIED' ? 'OFFER_SENT' : current;

    case 'REOPEN_NEGOTIATION':
      return current === 'OFFER_SENT' ? 'NEGOTIATING' : current;

    case 'OFFER_ACCEPTED':
      // OFFER_SENT veya NEGOTIATING -> ACCEPTED
      return (current === 'OFFER_SENT' || current === 'NEGOTIATING') ? 'ACCEPTED' : current;

    case 'OFFER_REJECTED':
      return (current === 'OFFER_SENT' || current === 'NEGOTIATING') ? 'REJECTED' : current;

    case 'EXPIRE':
      // DRAFT dışındaki her şey expire olabilir (senin iş kuralına göre revize edilebilir)
      return current === 'ACCEPTED' || current === 'REJECTED' ? current : 'EXPIRED';

    default:
      return current;
  }
}
TS

# 2B) deals.service.ts varsa patch, yoksa oluştur
if [ -f "src/deals/deals.service.ts" ]; then
  echo "==> src/deals/deals.service.ts bulundu; advanceDeal eklenecek (idempotent)."
else
  echo "==> src/deals/deals.service.ts yok; oluşturuluyor."
  cat > src/deals/deals.service.ts <<'TS'
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DealEvent, nextStatus } from './deals.engine';

@Injectable()
export class DealsService {
  constructor(private readonly prisma: PrismaService) {}

  async advanceDeal(dealId: string, event: DealEvent) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const current = deal.status as any;
    const next = nextStatus(current, event);

    if (next === current) {
      throw new BadRequestException(`No transition: ${current} + ${event}`);
    }

    const now = new Date();

    // Side-effect timestamps (minimal)
    const patch: any = {
      status: next,
      statusChangedAt: now,
    };

    if (next === 'QUALIFIED') patch.qualifiedAt = now;
    if (next === 'ACCEPTED') patch.acceptedAt = now;
    if (next === 'REJECTED') patch.rejectedAt = now;

    // EXPIRED ise expiresAt set edelim
    if (next === 'EXPIRED') patch.expiresAt = now;

    return this.prisma.deal.update({
      where: { id: dealId },
      data: patch,
    });
  }
}
TS
fi

# deals.controller.ts yoksa oluştur (varsa dokunmayalım, çakışma riskini azaltalım)
if [ -f "src/deals/deals.controller.ts" ]; then
  echo "==> src/deals/deals.controller.ts mevcut; dokunulmuyor (çakışma riski)."
else
  echo "==> src/deals/deals.controller.ts oluşturuluyor (POST /deals/:id/advance)."
  cat > src/deals/deals.controller.ts <<'TS'
import { Body, Controller, Param, Post } from '@nestjs/common';
import { DealsService } from './deals.service';
import { DealEvent } from './deals.engine';

@Controller('deals')
export class DealsController {
  constructor(private readonly deals: DealsService) {}

  @Post(':id/advance')
  advance(@Param('id') id: string, @Body() body: { event: DealEvent }) {
    return this.deals.advanceDeal(id, body.event);
  }
}
TS
fi

# deals.module.ts yoksa oluştur (varsa dokunmayalım)
if [ -f "src/deals/deals.module.ts" ]; then
  echo "==> src/deals/deals.module.ts mevcut; dokunulmuyor."
else
  echo "==> src/deals/deals.module.ts oluşturuluyor."
  cat > src/deals/deals.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { DealsService } from './deals.service';
import { DealsController } from './deals.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [DealsService],
  controllers: [DealsController],
  exports: [DealsService],
})
export class DealsModule {}
TS
fi

echo "==> 3) AppModule'a DealsModule ekleme (idempotent)"
APP_MOD="src/app.module.ts"
if [ -f "$APP_MOD" ]; then
  node - <<'NODE'
const fs = require("fs");
const p = "src/app.module.ts";
let t = fs.readFileSync(p, "utf8");

if (!t.includes("DealsModule")) {
  // import ekle
  if (!t.includes("from './deals/deals.module'") && !t.includes('from "../deals/deals.module"')) {
    t = t.replace(/(import\s+\{[\s\S]*?\}\s+from\s+'@nestjs\/common';\s*)/m,
      `$1\nimport { DealsModule } from './deals/deals.module';\n`);
  }

  // imports array'e ekle
  t = t.replace(/imports\s*:\s*\[([\s\S]*?)\]/m, (m, inner) => {
    if (inner.includes("DealsModule")) return m;
    const trimmed = inner.trim();
    if (!trimmed) return "imports: [DealsModule]";
    return `imports: [${inner.replace(/\s+$/,"")}, DealsModule]`;
  });

  fs.writeFileSync(p, t, "utf8");
  console.log("==> app.module.ts patched (DealsModule eklendi).");
} else {
  console.log("==> app.module.ts zaten DealsModule içeriyor.");
}
NODE
else
  echo "UYARI: src/app.module.ts bulunamadı; DealsModule otomatik eklenemedi."
fi

echo "==> 4) Prisma generate + migrate"
pnpm -s prisma generate --schema prisma/schema.prisma

# migrate dev: DB'ye yazar. DATABASE_URL çalışıyorsa sorunsuz geçer.
pnpm -s prisma migrate dev --name deal_status_lifecycle --schema prisma/schema.prisma

echo
echo "==> DONE: Deal otomasyonu çekirdeği kuruldu."
echo
echo "Test (DEV server açıkken):"
echo "  curl -s -X POST http://localhost:3001/deals/<DEAL_ID>/advance -H 'Content-Type: application/json' -d '{\"event\":\"QUESTIONS_COMPLETED\"}' | jq ."
echo
echo "NOT: Eğer pnpm start:dev çalışmıyorsa, şu komut terminali BLOKLAR (açık kalır):"
echo "  pnpm start:dev"
