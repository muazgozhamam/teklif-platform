#!/usr/bin/env bash
set -e

API_SRC="apps/api/src"
BROKER_DIR="$API_SRC/broker"
COMM_DIR="$API_SRC/commissions"

echo "==> Broker commissions controller ekleniyor"
mkdir -p "$BROKER_DIR"

cat > "$BROKER_DIR/broker-commissions.controller.ts" <<'EOC'
import { Controller, Post, Param, Body } from '@nestjs/common';
import { CommissionsService } from '../commissions/commissions.service';

@Controller('broker/deals')
export class BrokerCommissionsController {
  constructor(private readonly commissions: CommissionsService) {}

  @Post(':id/commission')
  createCommission(
    @Param('id') dealId: string,
    @Body() body: { amount: number; rate: number },
  ) {
    const result = this.commissions.calculate(body.amount, body.rate);

    return {
      dealId,
      ...result,
      status: 'CREATED',
    };
  }
}
EOC

echo "==> BrokerModule'a controller ekleniyor"
BROKER_MODULE="$BROKER_DIR/broker.module.ts"

# import ekle
if ! grep -q "BrokerCommissionsController" "$BROKER_MODULE"; then
  sed -i '' '1i\
import { BrokerCommissionsController } from "./broker-commissions.controller";\
' "$BROKER_MODULE"
fi

# controllers array'ine ekle
perl -0777 -i -pe '
s/controllers:\s*\[([^\]]*)\]/controllers: [\1, BrokerCommissionsController]/s
' "$BROKER_MODULE"

echo "==> TAMAM (watch mode reload edecek)"
