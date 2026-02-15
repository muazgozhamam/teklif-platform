#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
FILE="$ROOT/apps/api/src/leads/dto/lead-answer.dto.ts"

if [ ! -f "$FILE" ]; then
  echo "❌ Missing: $FILE"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/leads/dto/lead-answer.dto.ts")
orig = p.read_text(encoding="utf-8")

# Replace whole file with a clean, deterministic version.
clean = """import { IsOptional, IsString, IsNotEmpty } from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class LeadAnswerDto {
  /**
   * Canonical field name used by API.
   * Accepts legacy/alternate `field` and maps it into `key` before validation.
   */
  @ApiProperty({ required: true, example: 'city' })
  @Transform(({ value, obj }) => (value ?? obj?.field ?? '').toString().trim())
  @IsString()
  @IsNotEmpty()
  key!: string;

  /**
   * Legacy/alternate name; optional.
   */
  @ApiProperty({ required: false, example: 'city' })
  @Transform(({ value }) => (value == null ? undefined : value.toString()))
  @IsOptional()
  @IsString()
  field?: string;

  /**
   * Answer value (required).
   */
  @ApiProperty({ required: true, example: 'Konya' })
  @Transform(({ value }) => (value ?? '').toString().trim())
  @IsString()
  @IsNotEmpty()
  answer!: string;
}
"""

if orig == clean:
  raise SystemExit("❌ No changes applied (already clean?)")

bak = p.with_suffix(p.suffix + ".bak")
bak.write_text(orig, encoding="utf-8")
p.write_text(clean, encoding="utf-8")

print("✅ Fixed LeadAnswerDto (key/field mapping + required answer validation)")
print(" - Updated:", p)
print(" - Backup :", bak)
PY

echo
echo "==> Typecheck (API build)"
pnpm -C "$ROOT/apps/api" -s build
echo "✅ Done."
