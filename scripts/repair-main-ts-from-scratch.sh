#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$ROOT/apps/api/src/main.ts"

echo "==> Rewriting main.ts from scratch: $MAIN"

cat > "$MAIN" <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';
import { DevSeedService } from './dev-seed/dev-seed.service';

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

  // Optional dev seed (only when DEV_SEED=1)
  if (process.env.DEV_SEED === '1') {
    try {
      await app.get(DevSeedService).seed();
      // eslint-disable-next-line no-console
      console.log('DEV_SEED=1 -> seed completed');
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('DEV SEED ERROR:', e);
    }
  }

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

echo "OK: main.ts rewritten"

echo "==> Build only API to verify"
cd "$ROOT/apps/api"
pnpm -s build

echo
echo "DONE."
echo "Dev çalıştırmak için:"
echo "  cd $ROOT/apps/api && DEV_SEED=1 pnpm start:dev"
echo "Test:"
echo "  curl -i http://localhost:3001/health"
echo "  curl -i http://localhost:3001/docs"
