#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

if [ ! -d "$API" ]; then
  echo "apps/api not found. Run this from teklif-platform root."
  exit 1
fi

echo "==> Installing API dependencies..."
cd "$API"
pnpm add @nestjs/config @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt class-validator class-transformer
pnpm add -D @types/bcrypt @types/passport-jwt ts-node

echo "==> Updating Prisma schema..."
cat > "$API/prisma/schema.prisma" <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = "file:./dev.db"
}

enum Role {
  HUNTER
  AGENT
  BROKER
  ADMIN
}

model User {
  id           String   @id @default(uuid())
  email        String   @unique
  passwordHash String
  name         String
  role         Role     @default(HUNTER)
  isActive     Boolean  @default(true)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}
PRISMA

echo "==> Writing Prisma module/service..."
mkdir -p "$API/src/prisma"

cat > "$API/src/prisma/prisma.module.ts" <<'TS'
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
TS

cat > "$API/src/prisma/prisma.service.ts" <<'TS'
import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
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

echo "==> Writing Users module/service..."
mkdir -p "$API/src/users"

cat > "$API/src/users/users.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { UsersService } from './users.service';

@Module({
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
TS

cat > "$API/src/users/users.service.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Role, User } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  createUser(params: { email: string; passwordHash: string; name: string; role?: Role }): Promise<User> {
    return this.prisma.user.create({
      data: {
        email: params.email.toLowerCase().trim(),
        passwordHash: params.passwordHash,
        name: params.name.trim(),
        role: params.role ?? Role.HUNTER,
      },
    });
  }
}
TS

echo "==> Writing Auth module..."
mkdir -p "$API/src/auth/dto"

cat > "$API/src/auth/dto/login.dto.ts" <<'TS'
import { IsEmail, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(6)
  password!: string;
}
TS

cat > "$API/src/auth/jwt.guard.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
TS

cat > "$API/src/auth/jwt.strategy.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_SECRET', 'dev_secret_change_me'),
    });
  }

  async validate(payload: any) {
    return {
      id: payload.sub,
      email: payload.email,
      name: payload.name,
      role: payload.role,
    };
  }
}
TS

cat > "$API/src/auth/auth.service.ts" <<'TS'
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(private users: UsersService, private jwt: JwtService) {}

  async login(email: string, password: string) {
    const user = await this.users.findByEmail(email.toLowerCase().trim());
    if (!user || !user.isActive) throw new UnauthorizedException('Invalid credentials');

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    const token = await this.jwt.signAsync({
      sub: user.id,
      role: user.role,
      email: user.email,
      name: user.name,
    });

    return {
      accessToken: token,
      user: { id: user.id, email: user.email, name: user.name, role: user.role },
    };
  }
}
TS

cat > "$API/src/auth/auth.controller.ts" <<'TS'
import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './jwt.guard';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: any) {
    return { user: req.user };
  }
}
TS

cat > "$API/src/auth/auth.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';

import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [
    ConfigModule,
    PassportModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET', 'dev_secret_change_me'),
        signOptions: { expiresIn: '7d' },
      }),
    }),
  ],
  providers: [AuthService, JwtStrategy],
  controllers: [AuthController],
})
export class AuthModule {}
TS

echo "==> Writing Roles decorator/guard..."
mkdir -p "$API/src/common"

cat > "$API/src/common/roles.decorator.ts" <<'TS'
import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
TS

cat > "$API/src/common/roles.guard.ts" <<'TS'
import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { ROLES_KEY } from './roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const req = ctx.switchToHttp().getRequest();
    const user = req.user;
    if (!user?.role) throw new ForbiddenException('No role');

    if (!required.includes(user.role)) throw new ForbiddenException('Forbidden');
    return true;
  }
}
TS

echo "==> Updating AppModule..."
cat > "$API/src/app.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AppController } from './app.controller';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
TS

echo "==> Ensuring API .env has JWT_SECRET..."
if [ ! -f "$API/.env" ]; then
  cp "$API/.env.example" "$API/.env"
fi
if ! grep -q '^JWT_SECRET=' "$API/.env"; then
  echo 'JWT_SECRET="dev_secret_change_me"' >> "$API/.env"
fi

echo "==> Adding seed script + file..."
mkdir -p "$API/src/seed"

cat > "$API/src/seed/seed-admin.ts" <<'TS'
import * as bcrypt from 'bcrypt';
import { PrismaClient, Role } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();

  const email = (process.env.SEED_ADMIN_EMAIL || 'admin@teklif.local').toLowerCase().trim();
  const password = process.env.SEED_ADMIN_PASSWORD || 'Admin123!';
  const name = process.env.SEED_ADMIN_NAME || 'Admin';

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    console.log('Admin already exists:', email);
    await prisma.$disconnect();
    return;
  }

  const passwordHash = await bcrypt.hash(password, 12);

  await prisma.user.create({
    data: { email, passwordHash, name, role: Role.ADMIN },
  });

  console.log('Admin created:');
  console.log('  email:', email);
  console.log('  password:', password);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
TS

node -e "
const fs=require('fs');
const p='$API/package.json';
const j=JSON.parse(fs.readFileSync(p,'utf8'));
j.scripts=j.scripts||{};
j.scripts['seed:admin']=j.scripts['seed:admin']||'node -r ts-node/register src/seed/seed-admin.ts';
fs.writeFileSync(p, JSON.stringify(j,null,2));
"

echo "==> Prisma migrate + generate..."
pnpm prisma:migrate --name add_user_auth
pnpm prisma:generate

echo "==> Done. Next:"
echo "  cd apps/api && pnpm seed:admin"
echo "  cd apps/api && pnpm dev"
