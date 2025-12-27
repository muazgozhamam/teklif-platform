#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"

echo "==> [1/7] apps/api temizleniyor..."
rm -rf "$API_DIR"

echo "==> [2/7] NestJS API scaffold..."
mkdir -p "$API_DIR"
cd "$API_DIR"

npx --yes @nestjs/cli new api --skip-git --package-manager pnpm --directory .

echo "==> [3/7] Temel bağımlılıklar..."
pnpm add @nestjs/config @nestjs/swagger swagger-ui-express class-validator class-transformer
pnpm add @prisma/client
pnpm add -D prisma

echo "==> [4/7] Prisma init..."
npx prisma init --datasource-provider postgresql

cat > .env <<'ENV'
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/emlak?schema=public"
PORT=3001
NODE_ENV=development
ENV

cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  role      Role     @default(USER)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

enum Role {
  USER
  ADMIN
}
PRISMA

mkdir -p src/health src/prisma

cat > src/health/health.controller.ts <<'TS'
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  health() {
    return { ok: true };
  }
}
TS

cat > src/health/health.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

@Module({
  controllers: [HealthController],
})
export class HealthModule {}
TS

cat > src/prisma/prisma.service.ts <<'TS'
import { INestApplication, Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }

  async enableShutdownHooks(app: INestApplication) {
    this.$on('beforeExit', async () => {
      await app.close();
    });
  }
}
TS

cat > src/prisma/prisma.module.ts <<'TS'
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
TS

cat > src/app.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
  ],
})
export class AppModule {}
TS

cat > src/main.ts <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const config = new DocumentBuilder()
    .setTitle('Emlak API')
    .setVersion('1.0.0')
    .build();

  const doc = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, doc);

  await app.listen(3001);
  console.log('API http://localhost:3001');
}
bootstrap();
TS

npx prisma generate
npx prisma db push

echo "✅ API reset tamamlandı"

