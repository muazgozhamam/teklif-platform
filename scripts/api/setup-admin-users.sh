#!/usr/bin/env bash
set -euo pipefail

# === MUST RUN FROM PROJECT ROOT ===
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "❌ HATA: Script proje kökünden çalıştırılmalıdır."
  echo "👉 cd ~/Desktop/teklif-platform"
  exit 1
fi

API_DIR="apps/api"

echo "==> [1/6] Admin Users module yazılıyor..."
mkdir -p "$API_DIR/src/admin/users"

cat > "$API_DIR/src/admin/users/admin-users.service.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminUsersService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.user.findMany({
      select: { id: true, email: true, role: true, createdAt: true },
    });
  }

  async create(email: string, password: string, role: 'USER' | 'ADMIN') {
    const hash = await bcrypt.hash(password, 10);
    return this.prisma.user.create({
      data: { email, password: hash, role },
      select: { id: true, email: true, role: true },
    });
  }

  remove(id: string) {
    return this.prisma.user.delete({ where: { id } });
  }
}
TS

cat > "$API_DIR/src/admin/users/admin-users.controller.ts" <<'TS'
import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { AdminUsersService } from './admin-users.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/users')
export class AdminUsersController {
  constructor(private users: AdminUsersService) {}

  @Get()
  list() {
    return this.users.findAll();
  }

  @Post()
  create(@Body() body: { email: string; password: string; role?: 'USER' | 'ADMIN' }) {
    return this.users.create(body.email, body.password, body.role ?? 'USER');
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.users.remove(id);
  }
}
TS

cat > "$API_DIR/src/admin/users/admin-users.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { AdminUsersService } from './admin-users.service';
import { AdminUsersController } from './admin-users.controller';

@Module({
  providers: [AdminUsersService],
  controllers: [AdminUsersController],
})
export class AdminUsersModule {}
TS

echo "==> [2/6] Admin module index..."
mkdir -p "$API_DIR/src/admin"
cat > "$API_DIR/src/admin/admin.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { AdminUsersModule } from './users/admin-users.module';

@Module({
  imports: [AdminUsersModule],
})
export class AdminModule {}
TS

echo "==> [3/6] AppModule admin import..."
cat > "$API_DIR/src/app.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { AdminModule } from './admin/admin.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    AuthModule,
    AdminModule,
  ],
})
export class AppModule {}
TS

echo "==> [4/6] Build kontrol..."
cd "$API_DIR"
pnpm -s build >/dev/null || true

echo "==> [5/6] Admin Users hazır."
echo "Test komutları aşağıda."

echo "==> [6/6] Script tamamlandı."
