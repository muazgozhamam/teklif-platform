#!/usr/bin/env bash
set -e

RATE_SERVICE="apps/api/src/rates/rate.service.ts"

echo "==> RateService default rate ekleniyor"

cat <<'TS' > "$RATE_SERVICE"
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RateService {
  private readonly DEFAULT_RATE = 2;

  constructor(private readonly prisma: PrismaService) {}

  async resolve(brokerId?: string): Promise<number> {
    if (!brokerId) {
      return this.DEFAULT_RATE;
    }

    const rate = await this.prisma.rate.findFirst({
      where: { brokerId, active: true },
      orderBy: { createdAt: 'desc' },
    });

    return rate?.value ?? this.DEFAULT_RATE;
  }
}
TS

echo "✅ RateService artık asla null dönmez (default = 2)"
