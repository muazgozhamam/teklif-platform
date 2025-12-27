#!/usr/bin/env bash
set -e

API=apps/api/src

echo "==> Prisma altyapisi olusturuluyor"

mkdir -p $API/prisma

# prisma.service.ts
cat <<'SERVICE' > $API/prisma/prisma.service.ts
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit() {
    await this.$connect();
  }

  async enableShutdownHooks() {
    this.$on('beforeExit', async () => {
      await this.$disconnect();
    });
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
SERVICE

# prisma.module.ts
cat <<'MODULE' > $API/prisma/prisma.module.ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
MODULE

echo "==> AppModule'a PrismaModule ekleniyor"

APP_MODULE=$API/app.module.ts

if ! grep -q "PrismaModule" "$APP_MODULE"; then
  sed -i '' '1i\
import { PrismaModule } from "./prisma/prisma.module";\
' "$APP_MODULE"
fi

if grep -q "imports:" "$APP_MODULE"; then
  perl -0777 -i -pe '
    s/imports:\s*\[([^\]]*)\]/imports: [\1, PrismaModule]/s
  ' "$APP_MODULE"
else
  perl -0777 -i -pe '
    s/@Module\s*\(\s*\{/@Module({\n  imports: [PrismaModule],/s
  ' "$APP_MODULE"
fi

echo "==> Prisma altyapisi TAMAM"
