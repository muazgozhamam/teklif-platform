#!/usr/bin/env bash
set -euo pipefail

# === MUST RUN FROM PROJECT ROOT ===
if [ ! -f "pnpm-workspace.yaml" ]; then
  echo "❌ HATA: Script proje kökünden çalıştırılmalıdır."
  echo "👉 cd ~/Desktop/teklif-platform"
  exit 1
fi

API_DIR="apps/api"

echo "==> [1/8] Prisma schema: Lead + LeadAnswer ekleniyor..."
SCHEMA="$API_DIR/prisma/schema.prisma"

# Eğer Lead zaten varsa tekrar ekleme
if ! grep -q "^model Lead" "$SCHEMA"; then
  cat >> "$SCHEMA" <<'PRISMA'

model Lead {
  id          String       @id @default(cuid())
  createdAt   DateTime     @default(now())
  updatedAt   DateTime     @updatedAt

  // Kullanıcının ilk serbest metni
  initialText String

  // Durum (sonra pipeline yapacağız)
  status      LeadStatus   @default(OPEN)

  // İsteğe bağlı: admin/agent ataması (sonra User ile ilişkilendiririz)
  assignedTo  String?

  // Cevaplar
  answers     LeadAnswer[]
}

model LeadAnswer {
  id        String   @id @default(cuid())
  createdAt DateTime @default(now())

  leadId    String
  lead      Lead     @relation(fields: [leadId], references: [id], onDelete: Cascade)

  key       String   // soru anahtarı (e.g. "city")
  question  String
  answer    String
}

enum LeadStatus {
  OPEN
  IN_PROGRESS
  COMPLETED
  CANCELLED
}
PRISMA
fi

echo "==> [2/8] Lead module (public) yazılıyor..."
mkdir -p "$API_DIR/src/leads"

cat > "$API_DIR/src/leads/lead.questions.ts" <<'TS'
export type LeadQuestion = { key: string; question: string };

// Basit, genişletilebilir akış.
// Sonraki adımda: initialText'e göre (NLP) bazılarını otomatik dolduracağız.
export const LEAD_QUESTIONS: LeadQuestion[] = [
  { key: 'city', question: 'Hangi şehirde?' },
  { key: 'district', question: 'Hangi ilçe/mahalle?' },
  { key: 'type', question: 'Kiralık mı satılık mı? (kiralık/satılık)' },
  { key: 'rooms', question: 'Kaç oda? (örn: 2+1, 3+1)' },
];
TS

cat > "$API_DIR/src/leads/leads.service.ts" <<'TS'
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LEAD_QUESTIONS } from './lead.questions';

@Injectable()
export class LeadsService {
  constructor(private prisma: PrismaService) {}

  async create(initialText: string) {
    const lead = await this.prisma.lead.create({
      data: { initialText, status: 'OPEN' },
      select: { id: true, status: true, createdAt: true },
    });
    return lead;
  }

  async getLead(id: string) {
    const lead = await this.prisma.lead.findUnique({
      where: { id },
      include: { answers: { orderBy: { createdAt: 'asc' } } },
    });
    if (!lead) throw new NotFoundException('Lead not found');
    return lead;
  }

  async nextQuestion(id: string) {
    const lead = await this.getLead(id);
    const answeredKeys = new Set(lead.answers.map(a => a.key));
    const next = LEAD_QUESTIONS.find(q => !answeredKeys.has(q.key));

    if (!next) {
      // tamamlandı
      if (lead.status !== 'COMPLETED') {
        await this.prisma.lead.update({ where: { id }, data: { status: 'COMPLETED' } });
      }
      return { done: true };
    }

    // süreç başladı
    if (lead.status === 'OPEN') {
      await this.prisma.lead.update({ where: { id }, data: { status: 'IN_PROGRESS' } });
    }

    return { done: false, ...next };
  }

  async answer(id: string, key: string, answer: string) {
    const q = LEAD_QUESTIONS.find(x => x.key === key);
    if (!q) throw new NotFoundException('Unknown question key');

    // Aynı key daha önce cevaplandıysa update edelim
    const existing = await this.prisma.leadAnswer.findFirst({ where: { leadId: id, key } });
    if (existing) {
      return this.prisma.leadAnswer.update({
        where: { id: existing.id },
        data: { answer },
      });
    }

    return this.prisma.leadAnswer.create({
      data: { leadId: id, key, question: q.question, answer },
    });
  }
}
TS

cat > "$API_DIR/src/leads/leads.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { LeadsService } from './leads.service';

@Controller('leads')
export class LeadsController {
  constructor(private leads: LeadsService) {}

  // Public: kullanıcı ilk talebi girer
  @Post()
  create(@Body() body: { text: string }) {
    return this.leads.create(body.text);
  }

  // Public: sıradaki soru
  @Get(':id/next')
  next(@Param('id') id: string) {
    return this.leads.nextQuestion(id);
  }

  // Public: cevap kaydet
  @Post(':id/answer')
  answer(@Param('id') id: string, @Body() body: { key: string; answer: string }) {
    return this.leads.answer(id, body.key, body.answer);
  }

  // Public: lead + tüm cevaplar
  @Get(':id')
  get(@Param('id') id: string) {
    return this.leads.getLead(id);
  }
}
TS

cat > "$API_DIR/src/leads/leads.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { LeadsController } from './leads.controller';
import { LeadsService } from './leads.service';

@Module({
  controllers: [LeadsController],
  providers: [LeadsService],
})
export class LeadsModule {}
TS

echo "==> [3/8] Admin leads endpoint (ADMIN) yazılıyor..."
mkdir -p "$API_DIR/src/admin/leads"

cat > "$API_DIR/src/admin/leads/admin-leads.controller.ts" <<'TS'
import { Controller, Get, UseGuards } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { RolesGuard } from '../../common/roles/roles.guard';
import { Roles } from '../../common/roles/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin/leads')
export class AdminLeadsController {
  constructor(private prisma: PrismaService) {}

  @Get()
  list() {
    return this.prisma.lead.findMany({
      orderBy: { createdAt: 'desc' },
      include: { answers: true },
    });
  }
}
TS

cat > "$API_DIR/src/admin/leads/admin-leads.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { AdminLeadsController } from './admin-leads.controller';

@Module({
  controllers: [AdminLeadsController],
})
export class AdminLeadsModule {}
TS

echo "==> [4/8] AdminModule: AdminLeadsModule import..."
ADMIN_MODULE="$API_DIR/src/admin/admin.module.ts"
if [ -f "$ADMIN_MODULE" ]; then
  # Dosyayı standardize ediyoruz
  cat > "$ADMIN_MODULE" <<'TS'
import { Module } from '@nestjs/common';
import { AdminUsersModule } from './users/admin-users.module';
import { AdminLeadsModule } from './leads/admin-leads.module';

@Module({
  imports: [AdminUsersModule, AdminLeadsModule],
})
export class AdminModule {}
TS
else
  echo "❌ HATA: AdminModule yok. Önce admin users aşaması olmalı."
  exit 1
fi

echo "==> [5/8] AppModule: LeadsModule import..."
APP_MODULE="$API_DIR/src/app.module.ts"
cat > "$APP_MODULE" <<'TS'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { AdminModule } from './admin/admin.module';
import { LeadsModule } from './leads/leads.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    AuthModule,
    AdminModule,
    LeadsModule,
  ],
})
export class AppModule {}
TS

echo "==> [6/8] Prisma generate + db push..."
cd "$API_DIR"
npx prisma generate
npx prisma db push

echo "==> [7/8] Build kontrol..."
pnpm -s build >/dev/null || true

echo "==> [8/8] Lead/Talep akışı hazır."
echo "Test adımları:"
echo "  1) POST /leads"
echo "  2) GET /leads/:id/next"
echo "  3) POST /leads/:id/answer"
echo "  4) GET /leads/:id"
echo "Admin:"
echo "  GET /admin/leads (Bearer token)"
