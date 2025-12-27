#!/usr/bin/env bash
set -e

API=apps/api/src

echo "==> Rates modülü sıfırdan yazılıyor"
mkdir -p $API/rates

cat > $API/rates/rate.service.ts <<'TS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RateService {
  constructor(private prisma: PrismaService) {}

  async resolve(brokerId?: string): Promise<number> {
    if (!brokerId) return 2;
    const rate = await this.prisma.rate.findFirst({ where: { brokerId } });
    return rate?.rate ?? 2;
  }
}
TS

cat > $API/rates/rates.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { RateService } from './rate.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [RateService],
  exports: [RateService],
})
export class RatesModule {}
TS

echo "==> LedgerService garanti altına alınıyor"
mkdir -p $API/ledger

cat > $API/ledger/ledger.service.ts <<'TS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class LedgerService {
  constructor(private prisma: PrismaService) {}

  create(data: any) {
    return this.prisma.ledgerEntry.create({ data });
  }

  list() {
    return this.prisma.ledgerEntry.findMany({ orderBy: { createdAt: 'desc' } });
  }

  updateStatus(id: string, status: string) {
    return this.prisma.ledgerEntry.update({
      where: { id },
      data: { status },
    });
  }
}
TS

echo "==> LedgerController senkronize ediliyor"
cat > $API/ledger/ledger.controller.ts <<'TS'
import { Controller, Get, Patch, Param } from '@nestjs/common';
import { LedgerService } from './ledger.service';

@Controller('ledger/commissions')
export class LedgerController {
  constructor(private ledger: LedgerService) {}

  @Get()
  list() {
    return this.ledger.list();
  }

  @Patch(':id/pay')
  pay(@Param('id') id: string) {
    return this.ledger.updateStatus(id, 'PAID');
  }

  @Patch(':id/cancel')
  cancel(@Param('id') id: string) {
    return this.ledger.updateStatus(id, 'CANCELLED');
  }
}
TS

echo "==> AppModule imports düzeltiliyor"
APP=$API/app.module.ts

if ! grep -q "RatesModule" "$APP"; then
  sed -i '' '1i\
import { RatesModule } from "./rates/rates.module";\
' "$APP"
fi

perl -0777 -i -pe '
s/imports:\s*\[([^\]]*)\]/imports: [\1, RatesModule]/s
' "$APP"

echo "==> Broker rate → calculate → ledger zinciri sabitleniyor"
CTRL=$API/broker/broker-commissions.controller.ts

perl -0777 -i -pe '
s/this\.commissions\.calculate\([^\)]*\)/this.commissions.calculate(body.amount, rate)/s
' "$CTRL"

echo "==> TAMAM: Kod tutarlılığı sağlandı"
