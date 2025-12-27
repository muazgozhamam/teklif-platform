#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

if [ ! -d "$API" ]; then
  echo "apps/api not found. Run this from teklif-platform root."
  exit 1
fi

echo "==> Updating Prisma schema (Deal + CommissionEntry)..."
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

  // Referral
  invitedById  String?
  invitedBy    User?    @relation("UserInvitedBy", fields: [invitedById], references: [id])
  invitedUsers User[]   @relation("UserInvitedBy")

  inviteCode   String?  @unique

  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  leadsCreated  Lead[] @relation("LeadCreatedBy")
  leadsReviewed Lead[] @relation("LeadReviewedBy")

  dealsCreated  Deal[] @relation("DealCreatedBy")
  commissionEntries CommissionEntry[] @relation("CommissionBeneficiary")
}

model Lead {
  id           String   @id @default(uuid())

  createdById  String
  createdBy    User     @relation("LeadCreatedBy", fields: [createdById], references: [id])

  reviewedById String?
  reviewedBy   User?    @relation("LeadReviewedBy", fields: [reviewedById], references: [id])

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

  // Referral snapshot at creation time (JSON string)
  attributionPath String?

  submittedAt  DateTime @default(now())
  approvedAt   DateTime?
  rejectedAt   DateTime?

  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  deal Deal?
}

model Deal {
  id            String   @id @default(uuid())

  leadId        String   @unique
  lead          Lead     @relation(fields: [leadId], references: [id])

  createdById   String
  createdBy     User     @relation("DealCreatedBy", fields: [createdById], references: [id])

  salePrice     Float
  commissionRate Float   @default(0.04)  // 0.04 = %4
  commissionTotal Float

  status        String   @default("RECORDED") // RECORDED | CANCELLED

  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  ledgerEntries CommissionEntry[]
}

model CommissionEntry {
  id              String   @id @default(uuid())

  dealId          String
  deal            Deal     @relation(fields: [dealId], references: [id])

  // beneficiary can be null for PLATFORM / CENTER
  beneficiaryUserId String?
  beneficiaryUser   User?    @relation("CommissionBeneficiary", fields: [beneficiaryUserId], references: [id])

  beneficiaryRole  String    // HUNTER | AGENT | BROKER | PLATFORM
  level            Int?      // attribution level (0,1,2..), if applicable

  percent          Float     // e.g. 0.5
  amount           Float

  note             String?

  createdAt        DateTime @default(now())
}
PRISMA

echo "==> Writing Deals module..."
mkdir -p "$API/src/deals/dto"

cat > "$API/src/deals/dto/create-deal.dto.ts" <<'TS'
import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateDealDto {
  @IsString()
  leadId!: string;

  @IsNumber()
  @Min(0)
  salePrice!: number;

  // 0.04 = %4
  @IsOptional()
  @IsNumber()
  @Min(0)
  commissionRate?: number;
}
TS

cat > "$API/src/deals/deals.service.ts" <<'TS'
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type AttributionNode = {
  level: number;
  userId: string;
  role: string;
  email?: string;
  name?: string;
};

@Injectable()
export class DealsService {
  constructor(private prisma: PrismaService) {}

  private safeParseAttribution(json?: string | null): AttributionNode[] {
    if (!json) return [];
    try {
      const arr = JSON.parse(json);
      if (!Array.isArray(arr)) return [];
      return arr
        .filter(Boolean)
        .map((x: any) => ({
          level: Number(x.level ?? 0),
          userId: String(x.userId ?? ''),
          role: String(x.role ?? ''),
          email: x.email ? String(x.email) : undefined,
          name: x.name ? String(x.name) : undefined,
        }))
        .filter(x => x.userId.length > 0);
    } catch {
      return [];
    }
  }

  // Default distribution (can be made configurable later)
  private distribution() {
    return {
      level0: 0.50,      // lead creator (HUNTER/AGENT)
      level1: 0.20,      // inviter (upline)
      broker: 0.20,      // lead reviewer/approver
      platform: 0.10,    // center/platform
    };
  }

  async createDeal(params: { leadId: string; salePrice: number; commissionRate?: number; createdById: string }) {
    const lead = await this.prisma.lead.findUnique({ where: { id: params.leadId } });
    if (!lead) throw new NotFoundException('Lead not found');

    if (lead.status !== 'ACTIVE') {
      throw new BadRequestException('Lead must be ACTIVE to record a deal');
    }

    const existing = await this.prisma.deal.findUnique({ where: { leadId: params.leadId } });
    if (existing) throw new BadRequestException('Deal already recorded for this lead');

    const commissionRate = typeof params.commissionRate === 'number' ? params.commissionRate : 0.04;
    const commissionTotal = Number((params.salePrice * commissionRate).toFixed(2));

    const dist = this.distribution();
    const attribution = this.safeParseAttribution(lead.attributionPath);

    const level0 = attribution.find(x => x.level === 0);
    const level1 = attribution.find(x => x.level === 1);

    // broker = reviewedById (lead approved by)
    const brokerUserId = lead.reviewedById ?? null;

    // Build ledger rows
    const rows: Array<{
      beneficiaryUserId: string | null;
      beneficiaryRole: string;
      level: number | null;
      percent: number;
      amount: number;
      note: string;
    }> = [];

    const addRow = (r: typeof rows[number]) => {
      if (r.percent <= 0) return;
      const amount = Number((commissionTotal * r.percent).toFixed(2));
      if (amount <= 0) return;
      rows.push({ ...r, amount });
    };

    addRow({
      beneficiaryUserId: level0?.userId ?? null,
      beneficiaryRole: level0?.role || 'HUNTER',
      level: level0 ? 0 : null,
      percent: dist.level0,
      amount: 0,
      note: 'Lead owner (level 0)',
    });

    if (level1?.userId) {
      addRow({
        beneficiaryUserId: level1.userId,
        beneficiaryRole: level1.role || 'AGENT',
        level: 1,
        percent: dist.level1,
        amount: 0,
        note: 'Upline inviter (level 1)',
      });
    } else {
      addRow({
        beneficiaryUserId: null,
        beneficiaryRole: 'PLATFORM',
        level: null,
        percent: dist.level1,
        amount: 0,
        note: 'Upline missing -> platform',
      });
    }

    if (brokerUserId) {
      addRow({
        beneficiaryUserId: brokerUserId,
        beneficiaryRole: 'BROKER',
        level: null,
        percent: dist.broker,
        amount: 0,
        note: 'Approving broker',
      });
    } else {
      // fallback to platform if no reviewer
      addRow({
        beneficiaryUserId: null,
        beneficiaryRole: 'PLATFORM',
        level: null,
        percent: dist.broker,
        amount: 0,
        note: 'No reviewer -> platform',
      });
    }

    addRow({
      beneficiaryUserId: null,
      beneficiaryRole: 'PLATFORM',
      level: null,
      percent: dist.platform,
      amount: 0,
      note: 'Platform share',
    });

    // Fix rounding drift: adjust last row to match exact total
    const sum = rows.reduce((a, b) => a + b.amount, 0);
    const drift = Number((commissionTotal - sum).toFixed(2));
    if (Math.abs(drift) >= 0.01 && rows.length > 0) {
      rows[rows.length - 1].amount = Number((rows[rows.length - 1].amount + drift).toFixed(2));
    }

    const deal = await this.prisma.deal.create({
      data: {
        leadId: lead.id,
        createdById: params.createdById,
        salePrice: params.salePrice,
        commissionRate,
        commissionTotal,
        status: 'RECORDED',
        ledgerEntries: {
          create: rows.map(r => ({
            beneficiaryUserId: r.beneficiaryUserId,
            beneficiaryRole: r.beneficiaryRole,
            level: r.level,
            percent: r.percent,
            amount: r.amount,
            note: r.note,
          })),
        },
      },
      include: { ledgerEntries: true },
    });

    return deal;
  }

  listDeals() {
    return this.prisma.deal.findMany({
      orderBy: { createdAt: 'desc' },
      include: { lead: true },
    });
  }

  async getLedger(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const ledger = await this.prisma.commissionEntry.findMany({
      where: { dealId },
      orderBy: { amount: 'desc' },
      include: {
        beneficiaryUser: { select: { id: true, name: true, email: true, role: true } },
      },
    });

    return { deal, ledger };
  }
}
TS

cat > "$API/src/deals/deals.controller.ts" <<'TS'
import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { RolesGuard } from '../common/roles.guard';
import { Roles } from '../common/roles.decorator';
import { Role } from '../common/role.enum';
import { DealsService } from './deals.service';
import { CreateDealDto } from './dto/create-deal.dto';

@Controller('broker/deals')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.BROKER, Role.ADMIN)
export class DealsController {
  constructor(private deals: DealsService) {}

  @Post()
  create(@Req() req: any, @Body() dto: CreateDealDto) {
    return this.deals.createDeal({
      leadId: dto.leadId,
      salePrice: dto.salePrice,
      commissionRate: dto.commissionRate,
      createdById: req.user.id,
    });
  }

  @Get()
  list() {
    return this.deals.listDeals();
  }

  @Get(':id/ledger')
  ledger(@Param('id') id: string) {
    return this.deals.getLedger(id);
  }
}
TS

cat > "$API/src/deals/deals.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { DealsService } from './deals.service';
import { DealsController } from './deals.controller';

@Module({
  providers: [DealsService],
  controllers: [DealsController],
  exports: [DealsService],
})
export class DealsModule {}
TS

echo "==> Updating AppModule to include DealsModule..."
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
import { DealsModule } from './deals/deals.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    CommonModule,
    LeadsModule,
    BrokerModule,
    DealsModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
TS

echo "==> Prisma migrate + generate..."
cd "$API"
pnpm prisma:migrate --name add_deals_ledger
pnpm prisma:generate

echo "==> Done."
echo "Next:"
echo "  cd apps/api && pnpm dev"
echo "Test flow:"
echo "  1) Create lead -> approve -> create deal -> fetch ledger"
