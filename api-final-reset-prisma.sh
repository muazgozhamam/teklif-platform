#!/usr/bin/env bash
set -e

API="apps/api/src"

echo "==> 1. Prisma klasoru garanti ediliyor"
mkdir -p "$API/prisma"

echo "==> 2. PrismaService SIFIRDAN yaziliyor"
cat <<'TS' > "$API/prisma/prisma.service.ts"
import { INestApplication, Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit() {
    await this.$connect();
  }

  async enableShutdownHooks(app: INestApplication) {
    this.$on('beforeExit', async () => {
      await app.close();
    });
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
TS

echo "==> 3. @/prisma importlari RELATIVE yapiliyor"
grep -rl "@/prisma/prisma.service" "$API" | while read f; do
  sed -i '' "s|@/prisma/prisma.service|../prisma/prisma.service|g" "$f"
done

echo "==> 4. Build cache temizleniyor"
rm -rf apps/api/dist apps/api/.nest

echo "==> 5. API build"
pnpm --filter api build

echo "✅ BITTI: Prisma + API temiz build OK"
