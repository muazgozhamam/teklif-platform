#!/usr/bin/env bash
set -euo pipefail

[ -f "package.json" ] || { echo "HATA: apps/api kökünde değilsin."; exit 1; }
P="src/deals/deals.service.ts"
[ -f "$P" ] || { echo "HATA: $P yok."; exit 1; }

echo "==> 1) Backup al"
cp -f "$P" "${P}.bak.$(date +%Y%m%d-%H%M%S)"
echo "   OK: ${P}.bak.*"

echo
echo "==> 2) deals.service.ts yeniden yazılıyor (safe minimal implementation)"
cat > "$P" <<'TS'
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { DealEvent, nextStatus } from './deals.engine';

// Not: DealStatus enum'u Prisma'da var, ama burada string ile çalışmak daha az kırılgan.
// nextStatus zaten engine içinde karar veriyor.

@Injectable()
export class DealsService {
  constructor(private prisma: PrismaService) {}

  async getByLeadId(leadId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { leadId } });
    if (!deal) throw new NotFoundException('Deal not found');
    return deal;
  }

  async ensureForLead(leadId: string) {
    // leadId schema'da unique → upsert en doğru yol
    return this.prisma.deal.upsert({
      where: { leadId },
      update: {},
      create: { leadId },
    });
  }

  async advanceDeal(dealId: string, event: DealEvent) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const current = deal.status as any;
    const next = nextStatus(current, event);

    if (!next) {
      throw new BadRequestException(`No transition for status=${current} event=${event}`);
    }

    return this.prisma.deal.update({
      where: { id: dealId },
      data: { status: next as any },
    });
  }
}
TS

echo "==> deals.service.ts repaired."

echo
echo "==> 3) Build"
pnpm -s build

echo
echo "==> DONE"
echo "Sonraki adım: API'yi başlatıp route test edeceğiz."
