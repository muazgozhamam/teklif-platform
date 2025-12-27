#!/usr/bin/env bash
set -e

FILE="apps/api/src/commissions/commissions.service.ts"

echo "==> CommissionsService.calculate() güvenli hale getiriliyor"

cat <<'TS' > "$FILE"
import { Injectable } from '@nestjs/common';

@Injectable()
export class CommissionsService {
  private readonly DEFAULT_RATE = 2;

  calculate(amount: number, rate?: number) {
    const finalRate =
      typeof rate === 'number' && !isNaN(rate) ? rate : this.DEFAULT_RATE;

    const commission = Math.round((amount * finalRate) / 100);
    const net = amount - commission;

    return {
      amount,
      rate: finalRate,
      commission,
      net,
    };
  }
}
TS

echo "✅ calculate() artık asla null dönmez"
