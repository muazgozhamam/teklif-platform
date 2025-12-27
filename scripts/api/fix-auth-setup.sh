#!/usr/bin/env bash
set -euo pipefail

# === MUST RUN FROM PROJECT ROOT ===
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "❌ HATA: Script proje kökünden çalıştırılmalıdır."
  echo "👉 cd ~/Desktop/teklif-platform"
  exit 1
fi

API_DIR="apps/api"

if [ ! -d "$API_DIR" ]; then
  echo "❌ HATA: apps/api bulunamadı."
  exit 1
fi

echo "==> [1/9] API deps fix (Auth/Passport/Bcrypt/Dotenv)..."
cd "$API_DIR"
pnpm add @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt
pnpm add -D @types/passport-jwt @types/bcrypt dotenv

echo "==> [2/9] Prisma 7 config: dotenv load garanti..."
cat > prisma.config.ts <<'TS'
import "dotenv/config";
import { defineConfig } from "prisma/config";

export default defineConfig({
  datasource: {
    url: process.env.DATABASE_URL!,
  },
});
TS

echo "==> [3/9] Prisma schema (Prisma7 uyumlu, url yok) yazılıyor..."
cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  password  String
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

echo "==> [4/9] .env güvence (JWT_SECRET ekle)..."
if [ ! -f .env ]; then
  echo "❌ HATA: apps/api/.env yok. Önce db/prisma bootstrap çalışmalı."
  exit 1
fi

if ! grep -q "^JWT_SECRET=" .env; then
  echo 'JWT_SECRET="dev-secret"' >> .env
fi

echo "==> [5/9] PrismaService (Prisma7 + Nest lifecycle) yazılıyor..."
mkdir -p src/prisma
cat > src/prisma/prisma.service.ts <<'TS'
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
TS

echo "==> [6/9] Auth + Guards + Roles yazılıyor..."
mkdir -p src/auth src/common/roles

cat > src/auth/jwt-auth.guard.ts <<'TS'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
TS

cat > src/auth/jwt.strategy.ts <<'TS'
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_SECRET || 'dev-secret',
    });
  }

  async validate(payload: any) {
    return payload; // { sub, role }
  }
}
TS

cat > src/auth/auth.service.ts <<'TS'
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  async validateUser(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    return user;
  }

  async login(user: { id: string; role: string }) {
    return {
      access_token: this.jwt.sign({ sub: user.id, role: user.role }),
    };
  }
}
TS

cat > src/auth/auth.controller.ts <<'TS'
import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('login')
  async login(@Body() body: { email: string; password: string }) {
    const user = await this.auth.validateUser(body.email, body.password);
    return this.auth.login({ id: user.id, role: user.role });
  }
}
TS

cat > src/auth/auth.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { AuthController } from './auth.controller';

@Module({
  imports: [
    PassportModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret',
      signOptions: { expiresIn: '7d' },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
TS

cat > src/common/roles/roles.decorator.ts <<'TS'
import { SetMetadata } from '@nestjs/common';
export const ROLES_KEY = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
TS

cat > src/common/roles/roles.guard.ts <<'TS'
import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from './roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles) return true;

    const req = context.switchToHttp().getRequest();
    return roles.includes(req.user?.role);
  }
}
TS

echo "==> [7/9] AppModule + main.ts fix (AuthModule import + shutdown hooks)..."
cat > src/app.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    AuthModule,
  ],
})
export class AppModule {}
TS

# main.ts içine enableShutdownHooks garanti (varsa tekrar etmez diye komple standardize ediyoruz)
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

  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port);
  console.log(`API http://localhost:${port}`);
  console.log(`Swagger http://localhost:${port}/docs`);
}
bootstrap();
TS

echo "==> [8/9] Prisma generate + db push..."
npx prisma generate
npx prisma db push

echo "==> [9/9] Admin seed (node script, ts-node yok)..."
mkdir -p prisma/seed
cat > prisma/seed/admin.js <<'JS'
const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  const email = 'admin@local.dev';
  const password = await bcrypt.hash('admin123', 10);

  await prisma.user.upsert({
    where: { email },
    update: {},
    create: { email, password, role: 'ADMIN' },
  });

  console.log('✅ Admin user hazır:', email, ' / admin123');
}

main()
  .catch((e) => {
    console.error('SEED ERROR:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
JS

node - <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts["db:seed"] = "node prisma/seed/admin.js";
fs.writeFileSync('package.json', JSON.stringify(pkg,null,2));
console.log("OK: db:seed script set");
NODE

pnpm db:seed

echo "✅ FIX-AUTH tamamlandı."
echo "Çalıştır:"
echo "  cd apps/api && pnpm start:dev"
echo "Login test:"
echo "  curl -s -X POST http://localhost:3001/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"admin@local.dev\",\"password\":\"admin123\"}'"
