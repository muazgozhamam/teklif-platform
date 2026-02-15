import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditEntityType, Role } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

type Actor = {
  actorUserId?: string | null;
  actorRole?: string | null;
};

@Injectable()
export class NetworkService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async setParent(childId: string, parentId: string, actor?: Actor) {
    const child = await this.prisma.user.findUnique({
      where: { id: childId },
      select: { id: true, parentId: true },
    });
    if (!child) throw new NotFoundException('Child user not found');

    const parent = await this.prisma.user.findUnique({
      where: { id: parentId },
      select: { id: true, parentId: true },
    });
    if (!parent) throw new NotFoundException('Parent user not found');
    if (child.id === parent.id) {
      throw new BadRequestException('User cannot be parent of itself');
    }

    let currentParentId: string | null | undefined = parent.id;
    for (let depth = 0; depth < 10 && currentParentId; depth += 1) {
      if (currentParentId === child.id) {
        throw new BadRequestException('Hierarchy cycle detected');
      }
      const current = await this.prisma.user.findUnique({
        where: { id: currentParentId },
        select: { parentId: true },
      });
      currentParentId = current?.parentId;
    }

    if (currentParentId) {
      throw new BadRequestException('Hierarchy depth exceeds 10 levels');
    }

    const updated = await this.prisma.user.update({
      where: { id: childId },
      data: { parentId },
      select: { id: true, parentId: true },
    });

    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'ADMIN',
      action: 'NETWORK_PARENT_SET',
      entityType: AuditEntityType.USER,
      entityId: childId,
      beforeJson: { parentId: child.parentId ?? null },
      afterJson: { parentId: updated.parentId ?? null },
      metaJson: { childId, parentId },
    });

    return updated;
  }

  async getNetworkPath(userId: string) {
    const path: Array<{ id: string; parentId: string | null; email: string; role: Role }> = [];
    const visited = new Set<string>();
    let currentId: string | null = userId;

    for (let depth = 0; depth < 25 && currentId; depth += 1) {
      if (visited.has(currentId)) break;
      visited.add(currentId);
      const user = await this.prisma.user.findUnique({
        where: { id: currentId },
        select: { id: true, parentId: true, email: true, role: true },
      });
      if (!user) break;
      path.push(user);
      currentId = user.parentId;
    }

    if (path.length === 0) {
      throw new NotFoundException('User not found');
    }
    return path;
  }

  async getUpline(userId: string, maxDepth = 10) {
    const safeDepth = Math.min(Math.max(Number(maxDepth) || 10, 1), 50);
    const origin = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, parentId: true },
    });
    if (!origin) {
      throw new NotFoundException('User not found');
    }

    const visited = new Set<string>([origin.id]);
    const nodes: Array<{ id: string; role: Role; parentId: string | null }> = [];
    let currentParentId = origin.parentId;

    for (let depth = 0; depth < safeDepth && currentParentId; depth += 1) {
      if (visited.has(currentParentId)) break;
      visited.add(currentParentId);
      const current = await this.prisma.user.findUnique({
        where: { id: currentParentId },
        select: { id: true, role: true, parentId: true },
      });
      if (!current) break;
      nodes.push(current);
      currentParentId = current.parentId;
    }

    return nodes;
  }

  async getDirectParent(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        parent: {
          select: {
            id: true,
            role: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException('User not found');
    return user.parent ?? null;
  }

  async getCommissionSplitByRole(role: Role) {
    if (!Object.values(Role).includes(role)) {
      throw new BadRequestException('Invalid role');
    }
    const row = await this.prisma.commissionSplitConfig.findUnique({
      where: { role },
      select: { percent: true },
    });
    return row?.percent ?? null;
  }

  async getEffectiveCommissionSplit(role: Role, defaultPercent = 0) {
    if (!Object.values(Role).includes(role)) {
      throw new BadRequestException('Invalid role');
    }
    if (!Number.isFinite(defaultPercent) || defaultPercent < 0 || defaultPercent > 100) {
      throw new BadRequestException('defaultPercent must be between 0 and 100');
    }
    const configured = await this.getCommissionSplitByRole(role);
    return configured ?? defaultPercent;
  }

  async getSplitMap() {
    const rows = await this.prisma.commissionSplitConfig.findMany({
      select: { role: true, percent: true },
    });
    const byRole = new Map<Role, number>();
    for (const row of rows) byRole.set(row.role, row.percent);

    const map: Record<string, number | null> = {};
    for (const role of Object.values(Role)) {
      map[role] = byRole.get(role as Role) ?? null;
    }
    return map;
  }

  async setCommissionSplit(role: Role, percent: number, actor?: Actor) {
    if (!Object.values(Role).includes(role)) {
      throw new BadRequestException('Invalid role');
    }
    if (!Number.isFinite(percent) || percent < 0 || percent > 100) {
      throw new BadRequestException('percent must be between 0 and 100');
    }

    const existing = await this.prisma.commissionSplitConfig.findUnique({
      where: { role },
      select: { id: true, percent: true },
    });

    const config = await this.prisma.commissionSplitConfig.upsert({
      where: { role },
      update: { percent },
      create: { role, percent },
    });

    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'ADMIN',
      action: 'COMMISSION_SPLIT_CONFIG_SET',
      entityType: AuditEntityType.COMMISSION_CONFIG,
      entityId: config.id,
      beforeJson: existing ? { role, percent: existing.percent } : null,
      afterJson: { role, percent: config.percent },
      metaJson: { role, percent: config.percent },
    });

    return config;
  }
}
