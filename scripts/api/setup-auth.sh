#!/usr/bin/env bash
set -euo pipefail

# === MUST RUN FROM PROJECT ROOT ===
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "❌ HATA: Script proje kökünden çalıştırılmalıdır."
  echo "👉 cd ~/Desktop/teklif-platform"
  exit 1
fi

API_DIR="apps/api"

echo "==> [1/6] Auth bağımlılıkları kuruluyor..."
cd "$API_DIR"
pnpm add @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt
pnpm add -D @types/passport-jwt @types/bcrypt

echo "==> [2/6] Auth modülü oluşturuluyor..."
mkdir -p src/auth

cat > src/auth/auth.module.ts <<'TS'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [
    PassportModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret',
      signOptions: { expiresIn: '7d' },
    }),
  ],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
TS

cat > src/auth/auth.service.ts <<'TS'
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

  async validateUser(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException();

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) throw new UnauthorizedException();

    return user;
  }

  async login(user: any) {
    return {
      access_token: this.jwt.sign({
        sub: user.id,
        role: user.role,
      }),
    };
  }
}
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
    return payload;
  }
}
TS

echo "==> [3/6] Roles decorator + guard ekleniyor..."
mkdir -p src/common/roles

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

    const request = context.switchToHttp().getRequest();
    return roles.includes(request.user?.role);
  }
}
TS

echo "==> [4/6] Prisma User model güncelleniyor..."
sed -i '' 's/name      String?/name      String?\n  password  String/' prisma/schema.prisma

echo "==> [5/6] Admin seed script yazılıyor..."
mkdir -p prisma/seed

cat > prisma/seed/admin.ts <<'TS'
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const email = 'admin@local.dev';
  const password = await bcrypt.hash('admin123', 10);

  await prisma.user.upsert({
    where: { email },
    update: {},
    create: {
      email,
      password,
      role: 'ADMIN',
    },
  });

  console.log('✅ Admin user hazır:', email);
}

main().finally(() => prisma.$disconnect());
TS

node - <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts["db:seed"] = "ts-node prisma/seed/admin.ts";
fs.writeFileSync('package.json', JSON.stringify(pkg,null,2));
NODE

echo "==> [6/6] Prisma migrate + seed..."
set -a
source ./.env
set +a
npx prisma db push
pnpm db:seed

echo "✅ Auth + Roles + Admin seed tamamlandı"
