import { Injectable } from '@nestjs/common';
import { CommissionAuditAction, CommissionAuditEntityType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminAuditService {
  constructor(private readonly prisma: PrismaService) {}

  async list(params: { q?: string; action?: string; entityType?: string; take?: string; skip?: string }) {
    const take = Math.min(Math.max(Number(params.take || 20), 1), 100);
    const skip = Math.max(Number(params.skip || 0), 0);
    const q = String(params.q || '').trim();
    const action = String(params.action || '').trim().toUpperCase();
    const entityType = String(params.entityType || '').trim().toUpperCase();

    const where: Prisma.CommissionAuditEventWhereInput = {
      ...(action ? { action: action as CommissionAuditAction } : {}),
      ...(entityType ? { entityType: entityType as CommissionAuditEntityType } : {}),
      ...(q
        ? {
            OR: [
              { entityId: { contains: q, mode: 'insensitive' } },
              { actor: { email: { contains: q, mode: 'insensitive' } } },
            ],
          }
        : {}),
    };

    const [items, total] = await Promise.all([
      this.prisma.commissionAuditEvent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        include: { actor: { select: { email: true, role: true } } },
      }),
      this.prisma.commissionAuditEvent.count({ where }),
    ]);

    return {
      items: items.map((row) => ({
        id: row.id,
        createdAt: row.createdAt,
        action: row.action,
        canonicalAction: row.action,
        entity: row.entityType,
        canonicalEntity: row.entityType,
        entityId: row.entityId || '-',
        actor: row.actor ? { email: row.actor.email, role: row.actor.role } : null,
        metaJson: row.payloadJson || null,
      })),
      total,
      take,
      skip,
    };
  }
}
