#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api/src"

echo "==> 0) Guard"
test -d "$API" || { echo "❌ apps/api/src yok. Kök klasörde misin?"; exit 1; }

echo "==> 1) PrismaService temiz yazılıyor"
mkdir -p "$API/prisma"

cat > "$API/prisma/prisma.service.ts" <<'TS'
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
TS

echo "==> 2) PrismaModule export garanti ediliyor"
cat > "$API/prisma/prisma.module.ts" <<'TS'
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
TS

echo "==> 3) @/prisma importlari temizleniyor (global)"
# macOS güvenli perl replace
perl -pi -e "s#['\"]@/prisma/prisma\.service['\"]#'../prisma/prisma.service'#g" $(grep -rl "@/prisma/prisma.service" "$API" || true)

echo "==> 4) rates/rate.service.ts normalize ediliyor (value alanı + default)"
cat > "$API/rates/rate.service.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RateService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * brokerId verilirse broker'a özel aktif oranı döndürür.
   * Bulamazsa global aktif oranı döndürür.
   * Hiçbiri yoksa default 2 döndürür.
   */
  async resolve(brokerId?: string): Promise<number> {
    if (brokerId) {
      const byBroker = await this.prisma.rate.findFirst({
        where: { brokerId, active: true },
        orderBy: { createdAt: 'desc' },
      });
      if (byBroker?.value != null) return byBroker.value;
    }

    const globalRate = await this.prisma.rate.findFirst({
      where: { brokerId: null, active: true },
      orderBy: { createdAt: 'desc' },
    });

    return globalRate?.value ?? 2;
  }
}
TS

echo "==> 5) $transaction tx tipleri (TS7006) fix"
# $transaction(async (tx) => ...) geçen dosyalara Prisma importu + tx tipi ekle
FILES=$(grep -rl '\$transaction(async (tx)' "$API" || true)
if [ -n "${FILES:-}" ]; then
  for f in $FILES; do
    # Prisma import yoksa ekle
    if ! grep -q "from '@prisma/client'" "$f"; then
      # dosyanın en üstüne ekle
      perl -0777 -pi -e "s#\A#import { Prisma } from '@prisma/client';\n#s" "$f"
    fi
    perl -pi -e "s/\\$transaction\\(async \\(tx\\)/\\$transaction(async (tx: Prisma.TransactionClient)/g" "$f"
  done
fi

echo "==> 6) Cache/dist temizleniyor"
rm -rf "$ROOT/apps/api/dist" "$ROOT/apps/api/.nest"

echo "==> 7) Build"
pnpm --filter api build

echo "✅ BUILD OK"
echo
echo "Sonraki adım:"
echo "pnpm --filter api start:dev"
