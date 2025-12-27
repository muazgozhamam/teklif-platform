#!/usr/bin/env bash
set -e

API="apps/api/src"

echo "==> 1. PrismaService beforeExit TAMAMEN KALDIRILIYOR"

cat <<'TS' > "$API/prisma/prisma.service.ts"
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
TS

echo "==> 2. RateService prisma import path DUZELTILIYOR"

RATE_FILE="$API/rates/rate.service.ts"
if [ -f "$RATE_FILE" ]; then
  sed -i '' 's|../prisma/prisma.service|../../prisma/prisma.service|g' "$RATE_FILE"
fi

echo "==> 3. Cache temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> 4. API build"
pnpm --filter api build

echo "✅ TAMAM: BUILD BASARILI"
