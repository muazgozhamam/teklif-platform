#!/usr/bin/env bash
set -e

CTRL="apps/api/src/commissions/commissions.controller.ts"

echo "==> commissions.controller.ts overwrite ediliyor"

cat > "$CTRL" <<'EOC'
import { Controller, Get, Query } from '@nestjs/common';
import { CommissionsService } from './commissions.service';

@Controller('commissions')
export class CommissionsController {
  constructor(private readonly service: CommissionsService) {}

  @Get()
  root() {
    return { ok: true, message: 'commissions root' };
  }

  @Get('calc')
  calc(
    @Query('amount') amount: string,
    @Query('rate') rate: string,
  ) {
    return this.service.calculate(Number(amount), Number(rate));
  }
}
EOC

echo "==> controller guncellendi (watch mode reload edecek)"
