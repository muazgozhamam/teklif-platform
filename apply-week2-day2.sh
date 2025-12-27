#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

if [ ! -d "$API" ]; then
  echo "apps/api not found. Run this from teklif-platform root."
  exit 1
fi

echo "==> Writing Prisma schema (User + Lead)..."
cat > "$API/prisma/schema.prisma" <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = "file:./dev.db"
}

model User {
  id           String   @id @default(uuid())
  email        String   @unique
  passwordHash String
  name         String
  role         String   @default("HUNTER")
  isActive     Boolean  @default(true)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  leadsCreated  Lead[] @relation("LeadCreatedBy")
  leadsReviewed Lead[] @relation("LeadReviewedBy")
}

model Lead {
  id           String   @id @default(uuid())

  createdById  String
  createdBy    User     @relation("LeadCreatedBy", fields: [createdById], references: [id])

  reviewedById String?
  reviewedBy   User?    @relation("LeadReviewedBy", fields: [reviewedById], references: [id])

  // Lead core
  category     String   @default("KONUT") // KONUT | TICARI | ARSA
  status       String   @default("PENDING_BROKER_APPROVAL") // DRAFT | PENDING_BROKER_APPROVAL | ACTIVE | REJECTED

  title        String?
  city         String?
  district     String?
  neighborhood String?
  addressLine  String?

  ownerName    String?
  ownerPhone   String?

  price        Float?
  areaM2       Float?

  notes        String?
  brokerNote   String?

  submittedAt  DateTime @default(now())
  approvedAt   DateTime?
  rejectedAt   DateTime?

  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}
PRISMA

echo "==> Writing TS enums..."
mkdir -p "$API/src/common"

cat > "$API/src/common/lead.enums.ts" <<'TS'
export enum LeadCategory {
  KONUT = 'KONUT',
  TICARI = 'TICARI',
  ARSA = 'ARSA',
}

export enum LeadStatus {
  DRAFT = 'DRAFT',
  PENDING_BROKER_APPROVAL = 'PENDING_BROKER_APPROVAL',
  ACTIVE = 'ACTIVE',
  REJECTED = 'REJECTED',
}
TS

# role.enum.ts should already exist; ensure it exists
if [ ! -f "$API/src/common/role.enum.ts" ]; then
cat > "$API/src/common/role.enum.ts" <<'TS'
export enum Role {
  HUNTER = 'HUNTER',
  AGENT = 'AGENT',
  BROKER = 'BROKER',
  ADMIN = 'ADMIN',
}
TS
fi

echo "==> Ensuring RolesGuard is provided via a CommonModule..."
cat > "$API/src/common/common.module.ts" <<'TS'
import { Global, Module } from '@nestjs/common';
import { RolesGuard } from './roles.guard';

@Global()
@Module({
  providers: [RolesGuard],
  exports: [RolesGuard],
})
export class CommonModule {}
TS

echo "==> Updating AppModule to import CommonModule..."
# Overwrite app.module.ts to include CommonModule while preserving existing imports
cat > "$API/src/app.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AppController } from './app.controller';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { CommonModule } from './common/common.module';
import { LeadsModule } from './leads/leads.module';
import { BrokerModule } from './broker/broker.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    CommonModule,
    LeadsModule,
    BrokerModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
TS

echo "==> Writing Leads module/service/controller..."
mkdir -p "$API/src/leads/dto"

cat > "$API/src/leads/dto/create-lead.dto.ts" <<'TS'
import { IsEnum, IsNumber, IsOptional, IsString, Min, MinLength } from 'class-validator';
import { LeadCategory } from '../../common/lead.enums';

export class CreateLeadDto {
  @IsOptional()
  @IsEnum(LeadCategory)
  category?: LeadCategory;

  @IsOptional()
  @IsString()
  @MinLength(3)
  title?: string;

  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsString() district?: string;
  @IsOptional() @IsString() neighborhood?: string;
  @IsOptional() @IsString() addressLine?: string;

  @IsOptional() @IsString() ownerName?: string;
  @IsOptional() @IsString() ownerPhone?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  areaM2?: number;

  @IsOptional()
  @IsString()
  notes?: string;
}
TS

cat > "$API/src/leads/leads.service.ts" <<'TS'
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LeadStatus } from '../common/lead.enums';

@Injectable()
export class LeadsService {
  constructor(private prisma: PrismaService) {}

  createLead(userId: string, data: any) {
    return this.prisma.lead.create({
      data: {
        createdById: userId,
        category: data.category ?? 'KONUT',
        status: LeadStatus.PENDING_BROKER_APPROVAL,
        title: data.title ?? null,
        city: data.city ?? null,
        district: data.district ?? null,
        neighborhood: data.neighborhood ?? null,
        addressLine: data.addressLine ?? null,
        ownerName: data.ownerName ?? null,
        ownerPhone: data.ownerPhone ?? null,
        price: typeof data.price === 'number' ? data.price : null,
        areaM2: typeof data.areaM2 === 'number' ? data.areaM2 : null,
        notes: data.notes ?? null,
        submittedAt: new Date(),
      },
    });
  }

  listMyLeads(userId: string) {
    return this.prisma.lead.findMany({
      where: { createdById: userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getLeadForUser(userId: string, leadId: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');
    if (lead.createdById !== userId) throw new ForbiddenException('Forbidden');
    return lead;
  }

  listPendingForBroker() {
    return this.prisma.lead.findMany({
      where: { status: LeadStatus.PENDING_BROKER_APPROVAL },
      orderBy: { createdAt: 'asc' },
      include: { createdBy: { select: { id: true, name: true, email: true, role: true } } },
    });
  }

  async approveLead(leadId: string, brokerUserId: string, brokerNote?: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');

    return this.prisma.lead.update({
      where: { id: leadId },
      data: {
        status: LeadStatus.ACTIVE,
        reviewedById: brokerUserId,
        brokerNote: brokerNote ?? null,
        approvedAt: new Date(),
        rejectedAt: null,
      },
    });
  }

  async rejectLead(leadId: string, brokerUserId: string, brokerNote?: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');

    return this.prisma.lead.update({
      where: { id: leadId },
      data: {
        status: LeadStatus.REJECTED,
        reviewedById: brokerUserId,
        brokerNote: brokerNote ?? null,
        rejectedAt: new Date(),
        approvedAt: null,
      },
    });
  }
}
TS

cat > "$API/src/leads/leads.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { LeadsService } from './leads.service';
import { CreateLeadDto } from './dto/create-lead.dto';

@Controller('leads')
@UseGuards(JwtAuthGuard)
export class LeadsController {
  constructor(private leads: LeadsService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateLeadDto) {
    return this.leads.createLead(req.user.id, dto);
  }

  @Get('my')
  my(@Req() req: any) {
    return this.leads.listMyLeads(req.user.id);
  }

  @Get(':id')
  getOne(@Req() req: any, @Param('id') id: string) {
    return this.leads.getLeadForUser(req.user.id, id);
  }
}
TS

cat > "$API/src/leads/leads.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { LeadsService } from './leads.service';
import { LeadsController } from './leads.controller';

@Module({
  providers: [LeadsService],
  controllers: [LeadsController],
  exports: [LeadsService],
})
export class LeadsModule {}
TS

echo "==> Writing Broker module/controller..."
mkdir -p "$API/src/broker/dto"

cat > "$API/src/broker/dto/review-lead.dto.ts" <<'TS'
import { IsOptional, IsString, MinLength } from 'class-validator';

export class ReviewLeadDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  brokerNote?: string;
}
TS

cat > "$API/src/broker/broker.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Post, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { RolesGuard } from '../common/roles.guard';
import { Roles } from '../common/roles.decorator';
import { Role } from '../common/role.enum';
import { LeadsService } from '../leads/leads.service';
import { ReviewLeadDto } from './dto/review-lead.dto';

@Controller('broker')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.BROKER, Role.ADMIN)
export class BrokerController {
  constructor(private leads: LeadsService) {}

  @Get('leads/pending')
  pending() {
    return this.leads.listPendingForBroker();
  }

  @Post('leads/:id/approve')
  approve(@Req() req: any, @Param('id') id: string, @Body() dto: ReviewLeadDto) {
    return this.leads.approveLead(id, req.user.id, dto.brokerNote);
  }

  @Post('leads/:id/reject')
  reject(@Req() req: any, @Param('id') id: string, @Body() dto: ReviewLeadDto) {
    return this.leads.rejectLead(id, req.user.id, dto.brokerNote);
  }
}
TS

cat > "$API/src/broker/broker.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { BrokerController } from './broker.controller';
import { LeadsModule } from '../leads/leads.module';

@Module({
  imports: [LeadsModule],
  controllers: [BrokerController],
})
export class BrokerModule {}
TS

echo "==> Prisma migrate + generate..."
cd "$API"
pnpm prisma:migrate --name add_leads
pnpm prisma:generate

echo "==> Done."
echo "Next (in apps/api):"
echo "  pnpm dev"
echo "Test:"
echo "  (login -> token) then POST /leads"
