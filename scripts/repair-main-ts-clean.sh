#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT/apps/api"
MAIN="$API_DIR/src/main.ts"

echo "==> ROOT=$ROOT"
echo "==> API_DIR=$API_DIR"
echo "==> Rewriting main.ts: $MAIN"

cat > "$MAIN" <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Global filters
  app.useGlobalFilters(new PrismaExceptionFilter());

  // Swagger
  const config = new DocumentBuilder()
    .setTitle('Emlak API')
    .setVersion('1.0.0')
    .build();

  const doc = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, doc);

  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port);

  // eslint-disable-next-line no-console
  console.log(`API http://localhost:${port}`);
  // eslint-disable-next-line no-console
  console.log(`Swagger http://localhost:${port}/docs`);
}

bootstrap().catch((e) => {
  // eslint-disable-next-line no-console
  console.error('BOOTSTRAP ERROR:', e);
  process.exit(1);
});
TS

echo "OK: main.ts rewritten (clean)"

echo
echo "==> Clean dist + build (api)"
cd "$API_DIR"
rm -rf dist
pnpm -s build

echo
echo "DONE."
echo "Dev çalıştır:"
echo "  cd $API_DIR && DEV_SEED=1 pnpm start:dev"
echo "Test:"
echo "  curl -i http://localhost:3001/health"
echo "  curl -i http://localhost:3001/docs"
