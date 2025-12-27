#!/usr/bin/env bash
set -e

API_DIR="apps/api"
SRC="$API_DIR/src"
PRISMA_SCHEMA="$API_DIR/prisma/schema.prisma"

echo "==> Prisma modelleri ekleniyor (Rate)"

if ! grep -q "model Rate" "$PRISMA_SCHEMA"; then
cat >> "$PRISMA_SCHEMA" <<'EOM'

model Rate {
  id        String   @id @default(cuid())
  scope     String   // DEFAULT | BROKER | CAMPAIGN
  brokerId  String?  // BROKER scope
  value     Int
  startsAt  DateTime?
  endsAt    DateTime?
  active    Boolean  @default(true)
  createdAt DateTime @default(now())
}
EOM
fi

echo "==> Prisma migrate"
cd "$API_DIR"
pnpm prisma migrate dev --name add_rates

echo "==> RateService yaziliyor"
mkdir -p "$SRC/rates"

cat > "$SRC/rates/rate.service.ts" <<'EOS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RateService {
  constructor(private readonly prisma: PrismaService) {}

  async resolve(brokerId?: string): Promise<number> {
    const now = new Date();

    const campaign = await this.prisma.rate.findFirst({
      where: {
        scope: 'CAMPAIGN',
        active: true,
        OR: [
          { startsAt: null, endsAt: null },
          { startsAt: { lte: now }, endsAt: { gte: now } },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
    if (campaign) return campaign.value;

    if (brokerId) {
      const broker = await this.prisma.rate.findFirst({
        where: { scope: 'BROKER', brokerId, active: true },
        orderBy: { createdAt: 'desc' },
      });
      if (broker) return broker.value;
    }

    const def = await this.prisma.rate.findFirst({
      where: { scope: 'DEFAULT', active: true },
      orderBy: { createdAt: 'desc' },
    });
    if (def) return def.value;

    return 2; // güvenli fallback
  }

  create(data: any) {
    return this.prisma.rate.create({ data });
  }

  list() {
    return this.prisma.rate.findMany({ orderBy: { createdAt: 'desc' } });
  }
}
EOS

echo "==> RateController (admin)"
cat > "$SRC/rates/rate.controller.ts" <<'EOC'
import { Controller, Post, Body, Get, Param } from '@nestjs/common';
import { RateService } from './rate.service';

@Controller('admin/rates')
export class RateController {
  constructor(private readonly rates: RateService) {}

  @Post('default')
  setDefault(@Body() body: { value: number }) {
    return this.rates.create({ scope: 'DEFAULT', value: body.value });
  }

  @Post('broker/:brokerId')
  setBroker(
    @Param('brokerId') brokerId: string,
    @Body() body: { value: number },
  ) {
    return this.rates.create({ scope: 'BROKER', brokerId, value: body.value });
  }

  @Post('campaign')
  setCampaign(@Body() body: { value: number; startsAt?: string; endsAt?: string }) {
    return this.rates.create({
      scope: 'CAMPAIGN',
      value: body.value,
      startsAt: body.startsAt ? new Date(body.startsAt) : null,
      endsAt: body.endsAt ? new Date(body.endsAt) : null,
    });
  }

  @Get('resolve/:brokerId')
  resolve(@Param('brokerId') brokerId: string) {
    return this.rates.resolve(brokerId).then(value => ({ value }));
  }
}
EOC

echo "==> RatesModule"
cat > "$SRC/rates/rates.module.ts" <<'EOM'
import { Module } from '@nestjs/common';
import { RateService } from './rate.service';
import { RateController } from './rate.controller';

@Module({
  providers: [RateService],
  controllers: [RateController],
  exports: [RateService],
})
export class RatesModule {}
EOM

echo "==> AppModule'a RatesModule ekleniyor"
APP_MODULE="$SRC/app.module.ts"
if ! grep -q "RatesModule" "$APP_MODULE"; then
  sed -i '' '1i\
import { RatesModule } from "./rates/rates.module";\
' "$APP_MODULE"
fi
perl -0777 -i -pe '
s/imports:\s*\[([^\]]*)\]/imports: [\1, RatesModule]/s
' "$APP_MODULE"

echo "==> Broker controller rate resolve entegrasyonu"
BROKER_CTRL="$SRC/broker/broker-commissions.controller.ts"

if ! grep -q "RateService" "$BROKER_CTRL"; then
  sed -i '' '1i\
import { RateService } from "../rates/rate.service";\
' "$BROKER_CTRL"
fi

perl -0777 -i -pe '
s/constructor\(([^\)]*)\)/constructor($1, private readonly rates: RateService)/s
' "$BROKER_CTRL"

perl -0777 -i -pe '
s/const result = this\.commissions\.calculate\(body\.amount, body\.rate\);/const rate = body.rate ?? await this.rates.resolve(body.brokerId);\n    const result = this.commissions.calculate(body.amount, rate);/s
' "$BROKER_CTRL"

echo "==> TAMAM (watch mode reload edecek)"
