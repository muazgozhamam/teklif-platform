import { Injectable } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { AuditEntityType, Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../../audit/audit.service';

@Injectable()
export class AdminUsersService {
  constructor(private prisma: PrismaService, private audit: AuditService) {}

  private parseListQuery(query?: { take?: number; skip?: number; q?: string }) {
    const take = Math.min(Math.max(Number(query?.take ?? 50) || 50, 1), 100);
    const skip = Math.max(Number(query?.skip ?? 0) || 0, 0);
    const q = String(query?.q ?? '').trim();

    const where = q
      ? {
          OR: [
            { email: { contains: q, mode: 'insensitive' as const } },
            { name: { contains: q, mode: 'insensitive' as const } },
          ],
        }
      : undefined;
    return { take, skip, q, where };
  }

  findAll(query?: { take?: number; skip?: number; q?: string }) {
    const { take, skip, where } = this.parseListQuery(query);

    return this.prisma.user.findMany({
      where,
      take,
      skip,
      orderBy: { createdAt: 'desc' },
      select: { id: true, email: true, name: true, role: true, isActive: true, createdAt: true },
    });
  }

  async findAllPaged(query?: { take?: number; skip?: number; q?: string }) {
    const { take, skip, where } = this.parseListQuery(query);
    const [items, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        take,
        skip,
        orderBy: { createdAt: 'desc' },
        select: { id: true, email: true, name: true, role: true, isActive: true, createdAt: true },
      }),
      this.prisma.user.count({ where }),
    ]);
    return { items, total, take, skip };
  }

  async create(email: string, password: string, role: Role = Role.USER) {
    const hash = await bcrypt.hash(password, 10);
    const created = await this.prisma.user.create({
      data: { email, password: hash, role, isActive: true },
      select: { id: true, email: true, role: true, isActive: true },
    });
    await this.audit.log({
      action: 'USER_CREATED',
      entityType: 'USER',
      entityId: created.id,
      afterJson: { email: created.email, role: created.role, isActive: created.isActive },
    });
    return created;
  }

  async patchUser(
    id: string,
    patch: { role?: Role; isActive?: boolean },
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ) {
    const existing = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('User not found');

    const data: { role?: Role; isActive?: boolean } = {};
    if (patch.role !== undefined) data.role = patch.role;
    if (patch.isActive !== undefined) data.isActive = patch.isActive;

    if (Object.keys(data).length === 0) {
      throw new BadRequestException('No patch fields provided');
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data,
      select: { id: true, email: true, role: true, isActive: true, createdAt: true },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'ADMIN',
      action: 'USER_PATCHED',
      entityType: AuditEntityType.USER,
      entityId: id,
      afterJson: data,
    });
    return updated;
  }

  remove(id: string) {
    return this.prisma.user.delete({ where: { id } });
  }

  async setPassword(id: string, password: string) {
    const pw = (password ?? '').toString().trim();
    if (!pw) {
      throw new Error('password is required');
    }
    const hash = await bcrypt.hash(pw, 10);
    await this.prisma.user.update({
      where: { id },
      data: { password: hash },
    });
    await this.audit.log({
      action: 'USER_PASSWORD_SET',
      entityType: 'USER',
      entityId: id,
      metaJson: { updated: true },
    });
    return { ok: true };
  }

  async getCommissionConfig() {
    const row = await this.prisma.commissionConfig.upsert({
      where: { id: 'default' },
      update: {},
      create: { id: 'default' },
    });
    return row;
  }

  async patchCommissionConfig(patch: {
    baseRate?: number;
    hunterSplit?: number;
    brokerSplit?: number;
    consultantSplit?: number;
    platformSplit?: number;
  }, actor?: { actorUserId?: string | null; actorRole?: string | null }) {
    const current = await this.getCommissionConfig();

    const next = {
      baseRate: patch.baseRate ?? current.baseRate,
      hunterSplit: patch.hunterSplit ?? current.hunterSplit,
      brokerSplit: patch.brokerSplit ?? current.brokerSplit,
      consultantSplit: patch.consultantSplit ?? current.consultantSplit,
      platformSplit: patch.platformSplit ?? current.platformSplit,
    };

    if (next.baseRate <= 0) {
      throw new BadRequestException('baseRate must be > 0');
    }

    const splits = [next.hunterSplit, next.brokerSplit, next.consultantSplit, next.platformSplit];
    if (splits.some((v) => v < 0)) {
      throw new BadRequestException('split values cannot be negative');
    }
    const total = splits.reduce((a, b) => a + b, 0);
    if (total !== 100) {
      throw new BadRequestException('split total must be exactly 100');
    }

    return this.prisma.commissionConfig.update({
      where: { id: 'default' },
      data: next,
    });
  }
}
