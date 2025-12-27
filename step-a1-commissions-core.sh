#!/usr/bin/env bash
set -e

API_SRC="apps/api/src"
COMM_DIR="$API_SRC/commissions"
APP_MODULE="$API_SRC/app.module.ts"

echo "==> commissions klasoru hazirlaniyor"
mkdir -p "$COMM_DIR"

echo "==> commissions.service.ts"
cat > "$COMM_DIR/commissions.service.ts" <<'EOS'
import { Injectable } from '@nestjs/common';

@Injectable()
export class CommissionsService {
  calculate(amount: number, rate: number) {
    const commission = (amount * rate) / 100;
    return {
      amount,
      rate,
      commission,
      net: amount - commission,
    };
  }
}
EOS

echo "==> commissions.controller.ts"
cat > "$COMM_DIR/commissions.controller.ts" <<'EOC'
import { Controller, Get, Query } from '@nestjs/common';
import { CommissionsService } from './commissions.service';

@Controller('commissions')
export class CommissionsController {
  constructor(private readonly service: CommissionsService) {}

  @Get('calc')
  calc(
    @Query('amount') amount: string,
    @Query('rate') rate: string,
  ) {
    return this.service.calculate(Number(amount), Number(rate));
  }
}
EOC

echo "==> commissions.module.ts"
cat > "$COMM_DIR/commissions.module.ts" <<'EOM'
import { Module } from '@nestjs/common';
import { CommissionsController } from './commissions.controller';
import { CommissionsService } from './commissions.service';

@Module({
  controllers: [CommissionsController],
  providers: [CommissionsService],
  exports: [CommissionsService],
})
export class CommissionsModule {}
EOM

echo "==> AppModule'a CommissionsModule ekleniyor"

if ! grep -q "CommissionsModule" "$APP_MODULE"; then
  sed -i '' '1i\
import { CommissionsModule } from "./commissions/commissions.module";\
' "$APP_MODULE"
fi

perl -0777 -i -pe '
s/imports:\s*\[([^\]]*)\]/imports: [\1, CommissionsModule]/s
' "$APP_MODULE"

echo "==> Port 3001 temizleniyor"
PID=$(lsof -ti tcp:3001 || true)
[ -n "$PID" ] && kill -9 $PID

echo "==> SADECE API baslatiliyor"
cd apps/api
pnpm dev
