import { BadRequestException, ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditEntityType, Prisma, Role } from '@prisma/client';
import { createHash } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import {
  canonicalizeAction,
  canonicalizeEntity,
  isKnownEntityType,
  resolveActionFilterCandidates,
} from './audit-normalization';

export type AuditActor = {
  userId: string;
  role: string;
};

type AuditInput = {
  actorUserId?: string | null;
  actorRole?: string | null;
  action: AuditAction;
  entityType: AuditEntityType;
  entityId: string;
  beforeJson?: Prisma.JsonValue;
  afterJson?: Prisma.JsonValue;
  metaJson?: Prisma.JsonValue;
};

type AdminAuditQuery = {
  take?: number;
  skip?: number;
  entityType?: string;
  entityId?: string;
  actorUserId?: string;
  action?: string;
  from?: string;
  to?: string;
  q?: string;
};

type IntegrityQuery = {
  take?: number;
  skip?: number;
};

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async log(input: AuditInput) {
    try {
      const actorRole = input.actorRole ? String(input.actorRole).toUpperCase() : null;
      const createdAt = new Date();
      const latest = await this.prisma.auditLog.findFirst({
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        select: { hash: true },
      });
      const prevHash = latest?.hash ?? null;
      const hash = this.computeAuditHash({
        createdAt,
        actorUserId: input.actorUserId ?? null,
        actorRole: actorRole && this.isValidRole(actorRole) ? actorRole : null,
        action: input.action,
        entityType: input.entityType,
        entityId: input.entityId,
        beforeJson: input.beforeJson ?? null,
        afterJson: input.afterJson ?? null,
        metaJson: input.metaJson ?? null,
        prevHash,
      });
      return await this.prisma.auditLog.create({
        data: {
          createdAt,
          actorUserId: input.actorUserId ?? null,
          actorRole: actorRole && this.isValidRole(actorRole) ? (actorRole as Role) : null,
          action: input.action,
          entityType: input.entityType,
          entityId: input.entityId,
          beforeJson: input.beforeJson ?? undefined,
          afterJson: input.afterJson ?? undefined,
          metaJson: input.metaJson ?? undefined,
          prevHash,
          hash,
        },
      });
    } catch (error) {
      this.logger.warn(`audit log write failed action=${input.action} entity=${input.entityType}:${input.entityId}`);
      return null;
    }
  }

  async listByEntity(entityType: AuditEntityType, entityId: string, order: 'asc' | 'desc' = 'asc') {
    const rows = await this.prisma.auditLog.findMany({
      where: { entityType, entityId },
      orderBy: { createdAt: order },
      take: 500,
      include: {
        actorUser: { select: { id: true, email: true, name: true, role: true } },
      },
    });

    return rows.map((r) => ({
      id: r.id,
      createdAt: r.createdAt,
      actorUserId: r.actorUserId,
      actorRole: r.actorRole,
      actorEmail: r.actorUser?.email ?? null,
      actorName: r.actorUser?.name ?? null,
      action: r.action,
      canonicalAction: canonicalizeAction(r.action),
      entity: r.entityType,
      canonicalEntity: canonicalizeEntity(r.entityType),
      entityType: r.entityType,
      entityId: r.entityId,
      beforeJson: r.beforeJson,
      afterJson: r.afterJson,
      metaJson: r.metaJson,
      prevHash: r.prevHash ?? null,
      hash: r.hash ?? null,
    }));
  }

  async listAdmin(query: AdminAuditQuery) {
    const take = Math.min(Math.max(Number(query.take ?? 50) || 50, 1), 100);
    const skip = Math.max(Number(query.skip ?? 0) || 0, 0);
    const entityType = this.parseOptionalEntityType(query.entityType);
    const actions = this.parseActionFilter(query.action);
    const from = this.parseDate(query.from, 'from');
    const to = this.parseDate(query.to, 'to');
    const entityId = String(query.entityId ?? '').trim();
    const actorUserId = String(query.actorUserId ?? '').trim();
    const q = String(query.q ?? '').trim();

    const where: Prisma.AuditLogWhereInput = {};
    if (entityType) where.entityType = entityType;
    if (actions?.length) where.action = { in: actions };
    if (entityId) where.entityId = entityId;
    if (actorUserId) where.actorUserId = actorUserId;
    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = from;
      if (to) where.createdAt.lte = to;
    }

    if (q) {
      const orList: Prisma.AuditLogWhereInput[] = [
        { entityId: { contains: q, mode: 'insensitive' } },
        { actorUser: { is: { email: { contains: q, mode: 'insensitive' } } } },
        { actorUser: { is: { name: { contains: q, mode: 'insensitive' } } } },
      ];
      const qAction = this.parseOptionalAction(q);
      if (qAction.length) orList.push({ action: { in: qAction } });
      where.OR = orList;
    }

    const [rows, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        include: { actorUser: { select: { id: true, email: true, name: true, role: true } } },
        take,
        skip,
      }),
      this.prisma.auditLog.count({ where }),
    ]);

    const items = rows.map((r) => ({
      id: r.id,
      createdAt: r.createdAt,
      actorUserId: r.actorUserId,
      actorRole: r.actorRole,
      actor: r.actorUser
        ? { id: r.actorUser.id, email: r.actorUser.email, name: r.actorUser.name ?? null, role: r.actorUser.role }
        : null,
      action: r.action,
      canonicalAction: canonicalizeAction(r.action),
      entity: r.entityType,
      canonicalEntity: canonicalizeEntity(r.entityType),
      entityType: r.entityType,
      entityId: r.entityId,
      beforeJson: r.beforeJson,
      afterJson: r.afterJson,
      metaJson: r.metaJson,
      prevHash: r.prevHash ?? null,
      hash: r.hash ?? null,
    }));

    return { items, total, take, skip };
  }

  async assertCanReadLead(actor: AuditActor, leadId: string) {
    const role = String(actor.role || '').toUpperCase();
    if (role === 'ADMIN' || role === 'BROKER') return;
    if (role === 'HUNTER') {
      const lead = await this.prisma.lead.findUnique({
        where: { id: leadId },
        select: { sourceUserId: true },
      });
      if (lead?.sourceUserId === actor.userId) return;
    }
    throw new ForbiddenException('Forbidden resource');
  }

  async assertCanReadDeal(actor: AuditActor, dealId: string) {
    const role = String(actor.role || '').toUpperCase();
    if (role === 'ADMIN' || role === 'BROKER') return;
    if (role === 'CONSULTANT') {
      const deal = await this.prisma.deal.findUnique({
        where: { id: dealId },
        select: { consultantId: true },
      });
      if (deal?.consultantId === actor.userId) return;
    }
    throw new ForbiddenException('Forbidden resource');
  }

  async assertCanReadListing(actor: AuditActor, listingId: string) {
    const role = String(actor.role || '').toUpperCase();
    if (role === 'ADMIN' || role === 'BROKER') return;
    if (role === 'CONSULTANT') {
      const listing = await this.prisma.listing.findUnique({
        where: { id: listingId },
        select: { consultantId: true },
      });
      if (listing?.consultantId === actor.userId) return;
    }
    throw new ForbiddenException('Forbidden resource');
  }

  async integrityReport(query: IntegrityQuery) {
    const take = Math.min(Math.max(Number(query.take ?? 5000) || 5000, 1), 20_000);
    const skip = Math.max(Number(query.skip ?? 0) || 0, 0);

    const rows = await this.prisma.auditLog.findMany({
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take,
      skip,
      select: {
        id: true,
        createdAt: true,
        actorUserId: true,
        actorRole: true,
        action: true,
        entityType: true,
        entityId: true,
        beforeJson: true,
        afterJson: true,
        metaJson: true,
        prevHash: true,
        hash: true,
      },
    });

    let checkedRows = 0;
    const mismatchedRows: string[] = [];
    const missingHashRows: string[] = [];
    const brokenPrevRows: string[] = [];
    let previousHash: string | null = null;

    for (const row of rows) {
      if (!row.hash) {
        missingHashRows.push(row.id);
        previousHash = row.hash ?? null;
        continue;
      }
      checkedRows += 1;
      const computed = this.computeAuditHash({
        createdAt: row.createdAt,
        actorUserId: row.actorUserId ?? null,
        actorRole: row.actorRole ?? null,
        action: row.action,
        entityType: row.entityType,
        entityId: row.entityId,
        beforeJson: row.beforeJson ?? null,
        afterJson: row.afterJson ?? null,
        metaJson: row.metaJson ?? null,
        prevHash: row.prevHash ?? null,
      });
      if (computed !== row.hash) {
        mismatchedRows.push(row.id);
      }
      if (row.prevHash !== previousHash) {
        brokenPrevRows.push(row.id);
      }
      previousHash = row.hash;
    }

    return {
      ok: mismatchedRows.length === 0 && brokenPrevRows.length === 0,
      take,
      skip,
      totalRows: rows.length,
      checkedRows,
      missingHashRows: missingHashRows.length,
      mismatchedRows,
      brokenPrevRows,
    };
  }

  private parseDate(raw?: string, fieldName = 'date') {
    if (!raw) return undefined;
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) {
      throw new BadRequestException(`${fieldName} is invalid`);
    }
    return d;
  }

  private parseOptionalEntityType(v?: string): AuditEntityType | undefined {
    if (!v) return undefined;
    const up = String(v).trim().toUpperCase();
    if (!isKnownEntityType(up)) throw new BadRequestException('Invalid entityType');
    return up as AuditEntityType;
  }

  private parseOptionalAction(v?: string): AuditAction[] {
    if (!v) return [];
    return resolveActionFilterCandidates(v);
  }

  private parseActionFilter(v?: string): AuditAction[] | undefined {
    if (!v) return undefined;
    const actions = resolveActionFilterCandidates(v);
    if (!actions.length) throw new BadRequestException('Invalid action');
    return actions;
  }

  private isValidRole(v: string) {
    return ['USER', 'ADMIN', 'BROKER', 'CONSULTANT', 'HUNTER'].includes(v);
  }

  private stableStringify(value: unknown): string {
    if (value === null || value === undefined) return 'null';
    if (Array.isArray(value)) return `[${value.map((x) => this.stableStringify(x)).join(',')}]`;
    if (typeof value === 'object') {
      const obj = value as Record<string, unknown>;
      const keys = Object.keys(obj).sort();
      return `{${keys.map((k) => `${JSON.stringify(k)}:${this.stableStringify(obj[k])}`).join(',')}}`;
    }
    return JSON.stringify(value);
  }

  private computeAuditHash(input: {
    createdAt: Date;
    actorUserId: string | null;
    actorRole: string | null;
    action: string;
    entityType: string;
    entityId: string;
    beforeJson: Prisma.JsonValue | null;
    afterJson: Prisma.JsonValue | null;
    metaJson: Prisma.JsonValue | null;
    prevHash: string | null;
  }): string {
    const payload = [
      input.createdAt.toISOString(),
      input.actorUserId ?? '',
      input.actorRole ?? '',
      input.action,
      input.entityType,
      input.entityId,
      this.stableStringify(input.beforeJson),
      this.stableStringify(input.afterJson),
      this.stableStringify(input.metaJson),
      input.prevHash ?? '',
    ].join('|');
    return createHash('sha256').update(payload).digest('hex');
  }

}
