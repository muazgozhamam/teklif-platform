#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="$ROOT/apps/api"

DTO_DIR="$API/src/leads/dto"
mkdir -p "$DTO_DIR"

cat > "$DTO_DIR/lead-answer.dto.ts" <<'TS'
import { ApiProperty } from '@nestjs/swagger';

export class LeadAnswerDto {
  @ApiProperty({ example: 'city' })
  key: string;

  @ApiProperty({ example: 'Konya' })
  answer: string;
}

export class WizardAnswerDto {
  @ApiProperty({ example: 'Konya' })
  answer: string;
}
TS

CTRL="$API/src/leads/leads.controller.ts"

# import ekle (yoksa)
if ! rg -n "from './dto/lead-answer.dto'" "$CTRL" >/dev/null 2>&1; then
  perl -0777 -i -pe "s|(from '\\@nestjs/common';\\n)|\$1import { LeadAnswerDto, WizardAnswerDto } from './dto/lead-answer.dto';\\n|s" "$CTRL"
fi

# @Body() tiplerini değiştir
perl -0777 -i -pe "s/@Body\\(\\) body: \\{ answer: string \\}/@Body() body: WizardAnswerDto/gs" "$CTRL"
perl -0777 -i -pe "s/@Body\\(\\) body: \\{ key: string; answer: string \\}/@Body() body: LeadAnswerDto/gs" "$CTRL"

echo "OK: DTO patch uygulandı."
echo "Şimdi apps/api içinde build + restart:"
echo "  cd apps/api && pnpm -s build && pnpm start:dev"
