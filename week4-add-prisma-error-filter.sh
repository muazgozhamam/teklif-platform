#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API_DIR="$ROOT/apps/api"
MAIN_TS="$API_DIR/src/main.ts"
FILTER_TS="$API_DIR/src/common/filters/prisma-exception.filter.ts"

echo "==> ROOT: $ROOT"

mkdir -p "$(dirname "$FILTER_TS")"

cat > "$FILTER_TS" <<'TS'
import { ArgumentsHost, Catch, ExceptionFilter, HttpStatus } from '@nestjs/common';
import { Response } from 'express';
import { Prisma } from '@prisma/client';

@Catch()
export class PrismaExceptionFilter implements ExceptionFilter {
  catch(exception: any, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();

    // Always log full exception in dev
    // eslint-disable-next-line no-console
    console.error('🔥 EXCEPTION:', exception);

    // Prisma known errors
    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      return res.status(HttpStatus.BAD_REQUEST).json({
        statusCode: HttpStatus.BAD_REQUEST,
        error: 'PrismaClientKnownRequestError',
        code: exception.code,
        message: exception.message,
        meta: exception.meta,
      });
    }

    if (exception instanceof Prisma.PrismaClientValidationError) {
      return res.status(HttpStatus.BAD_REQUEST).json({
        statusCode: HttpStatus.BAD_REQUEST,
        error: 'PrismaClientValidationError',
        message: exception.message,
      });
    }

    // Nest HttpExceptions already have status
    const status = exception?.getStatus?.() ?? HttpStatus.INTERNAL_SERVER_ERROR;
    const message =
      exception?.response?.message ??
      exception?.message ??
      'Internal server error';

    return res.status(status).json({
      statusCode: status,
      message,
      error: exception?.name ?? 'Error',
    });
  }
}
TS

echo "==> WROTE: $FILTER_TS"

# Patch main.ts to register the filter
if [ ! -f "$MAIN_TS" ]; then
  echo "!! main.ts not found at: $MAIN_TS"
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
p = Path("apps/api/src/main.ts")
txt = p.read_text(encoding="utf-8")

if "PrismaExceptionFilter" in txt:
    print("==> main.ts already patched (PrismaExceptionFilter present).")
    raise SystemExit(0)

# ensure import
lines = txt.splitlines()
insert_at = 0
for i, line in enumerate(lines):
    if line.startswith("import "):
        insert_at = i + 1

lines.insert(insert_at, "import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';")

txt2 = "\n".join(lines)

# register filter after app creation (best effort)
needle = "const app = await NestFactory.create"
idx = txt2.find(needle)
if idx == -1:
    # fallback: try 'await NestFactory.create'
    needle = "await NestFactory.create"
    idx = txt2.find(needle)

if idx == -1:
    raise SystemExit("!! Could not locate NestFactory.create() line in main.ts")

# insert after the line containing create(...)
out_lines = txt2.splitlines()
for i, line in enumerate(out_lines):
    if "NestFactory.create" in line:
        # insert next line
        out_lines.insert(i+1, "  app.useGlobalFilters(new PrismaExceptionFilter());")
        break

p.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
print("==> Patched main.ts: registered PrismaExceptionFilter")
PY

echo "==> DONE. Restart your API dev server so changes take effect."
