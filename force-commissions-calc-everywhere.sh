#!/usr/bin/env bash
set -e

ROOT_CTRL="apps/api/src/commissions.controller.ts"
MOD_CTRL="apps/api/src/commissions/commissions.controller.ts"

CONTENT=$(cat <<'EOC'
import { Controller, Get, Query } from '@nestjs/common';
import { CommissionsService } from './commissions/commissions.service';

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
)

echo "==> Root controller overwrite"
mkdir -p "$(dirname "$ROOT_CTRL")"
echo "$CONTENT" > "$ROOT_CTRL"

echo "==> Module controller overwrite"
mkdir -p "$(dirname "$MOD_CTRL")"
sed "s|'./commissions/commissions.service'|'./commissions.service'|" <<< "$CONTENT" > "$MOD_CTRL"

echo "==> TAMAM (watch mode reload edecek)"
