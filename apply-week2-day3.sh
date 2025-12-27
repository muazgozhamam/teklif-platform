#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
API="$ROOT/apps/api"

if [ ! -d "$API" ]; then
  echo "apps/api not found. Run this from teklif-platform root."
  exit 1
fi

echo "==> Updating Prisma schema (User referrals + Lead attribution)..."
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
  attributionPath String? // e.g. [{"level":0,"userId":"...","role":"HUNTER"}, {"level":1,...}]

  submittedAt  DateTime @default(now())
  approvedAt   DateTime?
  rejectedAt   DateTime?

  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
}
PRISMA

echo "==> Writing DTOs for register..."
mkdir -p "$API/src/auth/dto"

cat > "$API/src/auth/dto/register.dto.ts" <<'TS'
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(6)
  password!: string;

  @IsString()
  @MinLength(2)
  name!: string;

  @IsOptional()
  @IsString()
  inviteCode?: string;
}
TS

echo "==> Ensuring role enum exists..."
mkdir -p "$API/src/common"
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

echo "==> Updating UsersService (invite + create)..."
cat > "$API/src/users/users.service.ts" <<'TS'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { User } from '@prisma/client';
import { Role } from '../common/role.enum';
import { randomBytes } from 'crypto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findByInviteCode(inviteCode: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { inviteCode } });
  }

  private makeInviteCode(): string {
    // 10 chars base32-like (upper) without confusing chars
    const raw = randomBytes(8).toString('hex').toUpperCase(); // 16 chars
    return raw.slice(0, 10);
  }

  async ensureInviteCode(userId: string): Promise<User> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error('User not found');

    if (user.inviteCode) return user;

    for (let i = 0; i < 10; i++) {
      const code = this.makeInviteCode();
      try {
        return await this.prisma.user.update({
          where: { id: userId },
          data: { inviteCode: code },
        });
      } catch (e: any) {
        // unique collision -> retry
      }
    }
    throw new Error('Could not generate unique invite code');
  }

  async createUser(params: {
    email: string;
    passwordHash: string;
    name: string;
    role?: Role;
    invitedById?: string | null;
  }): Promise<User> {
    // Always try to set an invite code at creation (retry if collision)
    for (let i = 0; i < 10; i++) {
      const inviteCode = this.makeInviteCode();
      try {
        return await this.prisma.user.create({
          data: {
            email: params.email.toLowerCase().trim(),
            passwordHash: params.passwordHash,
            name: params.name.trim(),
            role: params.role ?? Role.HUNTER,
            invitedById: params.invitedById ?? null,
            inviteCode,
          },
        });
      } catch (e: any) {
        // If email unique failed or inviteCode collision, bubble email errors quickly
        if (String(e?.message || '').includes('Unique constraint failed') && String(e?.message || '').includes('email')) {
          throw e;
        }
      }
    }
    throw new Error('Could not create user with unique invite code');
  }

  async getById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }
}
TS

echo "==> Adding UsersController (/users/me/invite)..."
cat > "$API/src/users/users.controller.ts" <<'TS'
import { Controller, Post, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private users: UsersService) {}

  @Post('me/invite')
  async myInvite(@Req() req: any) {
    const user = await this.users.ensureInviteCode(req.user.id);
    return { inviteCode: user.inviteCode };
  }
}
TS

echo "==> Updating UsersModule to include controller..."
cat > "$API/src/users/users.module.ts" <<'TS'
import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  providers: [UsersService],
  exports: [UsersService],
  controllers: [UsersController],
})
export class UsersModule {}
TS

echo "==> Updating AuthService to support register..."
cat > "$API/src/auth/auth.service.ts" <<'TS'
import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { Role } from '../common/role.enum';

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

  async register(params: { email: string; password: string; name: string; inviteCode?: string }) {
    const email = params.email.toLowerCase().trim();

    const exists = await this.users.findByEmail(email);
    if (exists) throw new BadRequestException('Email already in use');

    let invitedById: string | null = null;
    if (params.inviteCode) {
      const inviter = await this.users.findByInviteCode(params.inviteCode.trim().toUpperCase());
      if (!inviter) throw new BadRequestException('Invalid invite code');
      invitedById = inviter.id;
    }

    const passwordHash = await bcrypt.hash(params.password, 12);

    const user = await this.users.createUser({
      email,
      passwordHash,
      name: params.name,
      role: Role.HUNTER,
      invitedById,
    });

    // auto-login after register
    const token = await this.jwt.signAsync({
      sub: user.id,
      role: user.role,
      email: user.email,
      name: user.name,
    });

    return {
      accessToken: token,
      user: { id: user.id, email: user.email, name: user.name, role: user.role, invitedById: user.invitedById },
    };
  }
}
TS

echo "==> Updating AuthController (add /auth/register)..."
cat > "$API/src/auth/auth.controller.ts" <<'TS'
import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAuthGuard } from './jwt.guard';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  me(@Req() req: any) {
    return { user: req.user };
  }
}
TS

echo "==> Updating LeadsService to store attributionPath snapshot..."
cat > "$API/src/leads/leads.service.ts" <<'TS'
import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LeadStatus } from '../common/lead.enums';

@Injectable()
export class LeadsService {
  constructor(private prisma: PrismaService) {}

  private async buildAttributionPath(startUserId: string, maxDepth = 6) {
    const path: Array<{ level: number; userId: string; role: string; email?: string; name?: string }> = [];
    let currentId: string | null = startUserId;

    for (let level = 0; level < maxDepth && currentId; level++) {
      const u = await this.prisma.user.findUnique({
        where: { id: currentId },
        select: { id: true, role: true, invitedById: true, email: true, name: true },
      });
      if (!u) break;

      path.push({ level, userId: u.id, role: u.role, email: u.email, name: u.name });
      currentId = u.invitedById ?? null;
    }

    return JSON.stringify(path);
  }

  async createLead(userId: string, data: any) {
    const attributionPath = await this.buildAttributionPath(userId);

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
        attributionPath,
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

echo "==> Prisma migrate + generate..."
cd "$API"
pnpm prisma:migrate --name add_referrals
pnpm prisma:generate

echo "==> Done."
echo "Next:"
echo "  cd apps/api && pnpm dev"
echo "Test:"
echo "  1) login admin -> POST /users/me/invite"
echo "  2) POST /auth/register with inviteCode"
echo "  3) login new user -> POST /leads and check attributionPath"
