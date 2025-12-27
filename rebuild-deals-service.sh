#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/deals/deals.service.ts"

cat > "$FILE" <<'TS'
import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DealsService {
  constructor(private prisma: PrismaService) {}

  async getById(id: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id },
      include: {
        lead: true,
        consultant: true,
      },
    });

    if (!deal) {
      throw new NotFoundException('Deal not found');
    }

    return deal;
  }

  async matchDeal(id: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id },
    });

    if (!deal) {
      throw new NotFoundException('Deal not found');
    }

    // idempotent
    if (deal.status === 'ASSIGNED') {
      return deal;
    }

    const consultant = await this.prisma.user.findFirst({
      where: { role: 'CONSULTANT' },
    });

    if (!consultant) {
      throw new ConflictException('No consultant available');
    }

    return this.prisma.deal.update({
      where: { id },
      data: {
        consultantId: consultant.id,
        status: 'ASSIGNED',
      },
    });
  }
}
TS

echo "✅ deals.service.ts rebuilt cleanly"
echo "==> Building..."
cd apps/api
pnpm -s build
