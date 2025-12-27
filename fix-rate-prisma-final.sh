#!/usr/bin/env bash
set -e

API=apps/api/src

echo "==> RateService duzeltiliyor"

cat > $API/rates/rate.service.ts <<'TS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RateService {
  constructor(private prisma: PrismaService) {}

  async resolve(brokerId?: string): Promise<number> {
    if (!brokerId) return 2;

    const rate = await this.prisma.rate.findFirst({
      where: { brokerId, active: true },
    });

    return rate?.value ?? 2;
  }
}
TS

echo "==> PrismaModule export garanti ediliyor"

PRISMA_MOD=$API/prisma/prisma.module.ts

if ! grep -q "exports" "$PRISMA_MOD"; then
  perl -0777 -i -pe '
    s/@Module\s*\(\s*\{([^}]*)\}\s*\)/@Module({$1, exports: [PrismaService]})/s
  ' "$PRISMA_MOD"
fi

echo "==> Eski build temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> API build"
pnpm --filter api build

echo "==> API baslatiliyor"
node apps/api/dist/main.js &

echo "✅ TAMAM: Rate + Prisma zinciri duzeldi"
