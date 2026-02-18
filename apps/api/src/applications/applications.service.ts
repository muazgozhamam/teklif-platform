import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type PublicApplicationBody = {
  type: string;
  fullName?: string;
  phone?: string;
  email?: string;
  city?: string;
  district?: string;
  notes?: string;
  data?: Record<string, unknown>;
  source?: string;
};

type UpdateApplicationBody = {
  status?: AppStatus;
  priority?: AppPriority;
  assignedToUserId?: string | null;
  tags?: string[];
  notes?: string;
};

type AppType =
  | 'CUSTOMER_LEAD'
  | 'PORTFOLIO_LEAD'
  | 'CONSULTANT_CANDIDATE'
  | 'HUNTER_CANDIDATE'
  | 'BROKER_CANDIDATE'
  | 'PARTNER_CANDIDATE'
  | 'CORPORATE_LEAD'
  | 'SUPPORT_REQUEST'
  | 'COMPLAINT';
type AppStatus =
  | 'NEW'
  | 'QUALIFIED'
  | 'IN_REVIEW'
  | 'MEETING_SCHEDULED'
  | 'APPROVED'
  | 'ONBOARDED'
  | 'REJECTED'
  | 'CLOSED';
type AppPriority = 'P0' | 'P1' | 'P2';

const APP_TYPES: AppType[] = [
  'CUSTOMER_LEAD',
  'PORTFOLIO_LEAD',
  'CONSULTANT_CANDIDATE',
  'HUNTER_CANDIDATE',
  'BROKER_CANDIDATE',
  'PARTNER_CANDIDATE',
  'CORPORATE_LEAD',
  'SUPPORT_REQUEST',
  'COMPLAINT',
];
const APP_STATUSES: AppStatus[] = ['NEW', 'QUALIFIED', 'IN_REVIEW', 'MEETING_SCHEDULED', 'APPROVED', 'ONBOARDED', 'REJECTED', 'CLOSED'];
const APP_PRIORITIES: AppPriority[] = ['P0', 'P1', 'P2'];

const LEGACY_TYPE_MAP: Record<string, AppType> = {
  CONSULTANT: 'CONSULTANT_CANDIDATE',
  PARTNER: 'PARTNER_CANDIDATE',
  OWNER: 'PORTFOLIO_LEAD',
};

const ROLE_BY_TYPE: Record<AppType, Role> = {
  CUSTOMER_LEAD: Role.CONSULTANT,
  PORTFOLIO_LEAD: Role.CONSULTANT,
  CONSULTANT_CANDIDATE: Role.ADMIN,
  HUNTER_CANDIDATE: Role.BROKER,
  BROKER_CANDIDATE: Role.ADMIN,
  PARTNER_CANDIDATE: Role.BROKER,
  CORPORATE_LEAD: Role.ADMIN,
  SUPPORT_REQUEST: Role.ADMIN,
  COMPLAINT: Role.ADMIN,
};

@Injectable()
export class ApplicationsService {
  constructor(private readonly prisma: PrismaService) {}

  private get db(): any {
    return this.prisma as any;
  }

  private isMissingApplicationTable(error: unknown): boolean {
    if (!error || typeof error !== 'object') return false;
    const e = error as { code?: string; message?: string };
    return e.code === 'P2021' || String(e.message || '').includes('public.Application');
  }

  private normalizeType(raw: string): AppType {
    const fromLegacy = LEGACY_TYPE_MAP[String(raw || '').toUpperCase()];
    if (fromLegacy) return fromLegacy;
    const normalized = String(raw || '').toUpperCase();
    if (APP_TYPES.includes(normalized as AppType)) {
      return normalized as AppType;
    }
    throw new BadRequestException('Invalid application type');
  }

  private normalizePhone(phone: string) {
    return String(phone || '').replace(/[^\d+]/g, '').trim();
  }

  private normalizeEmail(email?: string) {
    const v = String(email || '').trim().toLowerCase();
    return v || undefined;
  }

  private buildDedupeKey(type: AppType, phone: string, email?: string) {
    const bucket = new Date().toISOString().slice(0, 10);
    const identity = email || phone;
    return `${type}:${identity}:${bucket}`;
  }

  private ensureBaseFields(dto: PublicApplicationBody) {
    const fullName = String(dto.fullName || '').trim();
    const phone = this.normalizePhone(String(dto.phone || ''));
    if (!fullName) throw new BadRequestException('fullName is required');
    if (!phone) throw new BadRequestException('phone is required');
    return { fullName, phone };
  }

  private async emitEvent(
    applicationId: string,
    eventType:
      | 'CREATED'
      | 'STATUS_CHANGED'
      | 'ASSIGNED'
      | 'NOTE_ADDED'
      | 'TAG_ADDED'
      | 'TAG_REMOVED'
      | 'CLOSED',
    actorUserId?: string | null,
    meta?: Record<string, unknown>,
  ) {
    await this.db.applicationEvent.create({
      data: {
        applicationId,
        actorUserId: actorUserId || null,
        eventType,
        meta: meta || undefined,
      },
    });
  }

  async createFromPublic(dto: PublicApplicationBody) {
    const type = this.normalizeType(dto.type);
    const { fullName, phone } = this.ensureBaseFields(dto);
    const email = this.normalizeEmail(dto.email);
    const dedupeKey = this.buildDedupeKey(type, phone, email);

    const existing = await this.db.application.findUnique({ where: { dedupeKey } });
    if (existing) {
      return { ok: true, deduped: true, id: existing.id };
    }

    const now = new Date();
    const created = await this.db.application.create({
      data: {
        type,
        status: 'NEW',
        fullName,
        phone,
        email,
        city: dto.city?.trim() || null,
        district: dto.district?.trim() || null,
        notes: dto.notes?.trim() || null,
        source: dto.source?.trim() || 'homepage',
        payload: dto.data || {},
        priority: 'P2',
        dedupeKey,
        lastActivityAt: now,
        slaFirstResponseAt: new Date(now.getTime() + 60 * 60 * 1000),
      },
      select: { id: true },
    });

    await this.emitEvent(created.id, 'CREATED', null, { source: dto.source || 'homepage' });

    return { ok: true, deduped: false, id: created.id };
  }

  async listForAdmin(query: {
    type?: string;
    status?: string;
    q?: string;
    assignedTo?: string;
    priority?: string;
    take?: number;
    skip?: number;
    from?: string;
    to?: string;
  }) {
    const take = Math.min(Math.max(Number(query.take || 20), 1), 100);
    const skip = Math.max(Number(query.skip || 0), 0);

    const where: any = {};
    if (query.type) {
      const parts = query.type
        .split(',')
        .map((v) => v.trim())
        .filter(Boolean);
      if (parts.length > 1) {
        where.type = { in: parts.map((p) => this.normalizeType(p)) };
      } else {
        where.type = this.normalizeType(query.type);
      }
    }
    if (query.status && APP_STATUSES.includes(query.status as AppStatus)) {
      where.status = query.status as AppStatus;
    }
    if (query.priority && APP_PRIORITIES.includes(query.priority as AppPriority)) {
      where.priority = query.priority as AppPriority;
    }
    if (query.assignedTo) where.assignedToUserId = query.assignedTo;
    if (query.from || query.to) {
      where.createdAt = {
        gte: query.from ? new Date(query.from) : undefined,
        lte: query.to ? new Date(query.to) : undefined,
      };
    }
    const q = String(query.q || '').trim();
    if (q) {
      where.OR = [
        { fullName: { contains: q, mode: 'insensitive' } },
        { email: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
      ];
    }

    try {
      const [items, total] = await Promise.all([
        this.db.application.findMany({
          where,
          take,
          skip,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          include: {
            assignedTo: { select: { id: true, name: true, email: true, role: true } },
            _count: { select: { appNotes: true, events: true } },
          },
        }),
        this.db.application.count({ where }),
      ]);

      return { items, total, take, skip };
    } catch (error) {
      if (this.isMissingApplicationTable(error)) {
        return { items: [], total: 0, take, skip, migrationRequired: true };
      }
      throw error;
    }
  }

  async getOneForAdmin(id: string) {
    let row: any;
    try {
      row = await this.db.application.findUnique({
        where: { id },
        include: {
          assignedTo: { select: { id: true, name: true, email: true, role: true } },
          appNotes: {
            orderBy: { createdAt: 'desc' },
            include: { author: { select: { id: true, name: true, email: true, role: true } } },
          },
          events: { orderBy: { createdAt: 'desc' }, take: 50 },
        },
      });
    } catch (error) {
      if (this.isMissingApplicationTable(error)) {
        throw new BadRequestException('CRM tabloları henüz migrate edilmedi: Application');
      }
      throw error;
    }
    if (!row) throw new NotFoundException('Application not found');
    return row;
  }

  async patchForAdmin(id: string, body: UpdateApplicationBody, actorUserId?: string) {
    const current = await this.db.application.findUnique({ where: { id } });
    if (!current) throw new NotFoundException('Application not found');

    const nextTags = Array.isArray(body.tags) ? body.tags.map((t) => String(t).trim()).filter(Boolean) : current.tags;
    const data: any = {
      lastActivityAt: new Date(),
      tags: nextTags,
    };

    if (body.status && APP_STATUSES.includes(body.status)) {
      data.status = body.status;
      if (!current.firstResponseAt && body.status !== 'NEW') {
        data.firstResponseAt = new Date();
      }
    }
    if (body.priority && APP_PRIORITIES.includes(body.priority)) {
      data.priority = body.priority;
    }
    if (Object.prototype.hasOwnProperty.call(body, 'assignedToUserId')) {
      data.assignedTo = body.assignedToUserId ? { connect: { id: body.assignedToUserId } } : { disconnect: true };
    }
    if (body.notes) {
      data.notes = body.notes;
    }

    const updated = await this.db.application.update({ where: { id }, data });
    if (body.status && body.status !== current.status) {
      await this.emitEvent(id, 'STATUS_CHANGED', actorUserId, { from: current.status, to: body.status });
    }
    if (body.priority && body.priority !== current.priority) {
      await this.emitEvent(id, 'STATUS_CHANGED', actorUserId, { priorityFrom: current.priority, priorityTo: body.priority });
    }
    if (Object.prototype.hasOwnProperty.call(body, 'assignedToUserId')) {
      await this.emitEvent(id, 'ASSIGNED', actorUserId, { assignedToUserId: body.assignedToUserId || null });
    }
    if (Array.isArray(body.tags)) {
      const added = nextTags.filter((t) => !current.tags.includes(t));
      const removed = current.tags.filter((t) => !nextTags.includes(t));
      if (added.length) await this.emitEvent(id, 'TAG_ADDED', actorUserId, { tags: added });
      if (removed.length) await this.emitEvent(id, 'TAG_REMOVED', actorUserId, { tags: removed });
    }
    return updated;
  }

  async addNote(id: string, actorUserId: string, body: string) {
    const text = String(body || '').trim();
    if (!text) throw new BadRequestException('note body is required');

    const app = await this.db.application.findUnique({ where: { id } });
    if (!app) throw new NotFoundException('Application not found');

    const now = new Date();
    const note = await this.db.applicationNote.create({
      data: {
        applicationId: id,
        authorUserId: actorUserId,
        body: text,
      },
      include: { author: { select: { id: true, name: true, email: true, role: true } } },
    });

    await this.db.application.update({
      where: { id },
      data: {
        lastActivityAt: now,
        firstResponseAt: app.firstResponseAt ?? now,
      },
    });

    await this.emitEvent(id, 'NOTE_ADDED', actorUserId, { noteId: note.id });
    return note;
  }

  private async pickRoundRobinAssignee(role: Role) {
    const users = await this.prisma.user.findMany({
      where: { role, isActive: true },
      select: { id: true, name: true, email: true },
      orderBy: { createdAt: 'asc' },
    });
    if (!users.length) return null;

    const loads = await Promise.all(
      users.map(async (u) => ({
        user: u,
        activeCount: await this.db.application.count({
          where: {
            assignedToUserId: u.id,
            status: { in: ['NEW', 'QUALIFIED', 'IN_REVIEW', 'MEETING_SCHEDULED'] },
          },
        }),
      })),
    );

    loads.sort((a, b) => a.activeCount - b.activeCount);
    return loads[0]?.user || null;
  }

  async assign(id: string, actorUserId: string, body: { userId?: string; role?: Role }) {
    const app = await this.db.application.findUnique({ where: { id } });
    if (!app) throw new NotFoundException('Application not found');

    let assigneeId = body.userId?.trim();
    if (!assigneeId) {
      const role = body.role || ROLE_BY_TYPE[app.type] || Role.ADMIN;
      const picked = await this.pickRoundRobinAssignee(role);
      if (!picked) throw new BadRequestException(`No active user found for role ${role}`);
      assigneeId = picked.id;
    }

    const updated = await this.db.application.update({
      where: { id },
      data: {
        assignedTo: { connect: { id: assigneeId } },
        lastActivityAt: new Date(),
      },
      include: { assignedTo: { select: { id: true, name: true, email: true, role: true } } },
    });

    await this.emitEvent(id, 'ASSIGNED', actorUserId, { assignedToUserId: assigneeId });
    return updated;
  }

  async close(id: string, actorUserId: string, reason?: string) {
    const app = await this.db.application.findUnique({ where: { id } });
    if (!app) throw new NotFoundException('Application not found');

    const updated = await this.db.application.update({
      where: { id },
      data: {
        status: 'CLOSED',
        notes: reason ? `${app.notes ? `${app.notes}\n` : ''}Kapatma notu: ${reason}` : app.notes,
        lastActivityAt: new Date(),
      },
    });
    await this.emitEvent(id, 'CLOSED', actorUserId, { reason: reason || null });
    return updated;
  }

  async getOverview() {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    let newToday = 0;
    let qualified = 0;
    let inReview = 0;
    let totalOpen = 0;
    let breaches = 0;
    let responded: Array<{ createdAt: Date; firstResponseAt: Date | null }> = [];

    try {
      [newToday, qualified, inReview, totalOpen, breaches] = await Promise.all([
        this.db.application.count({ where: { createdAt: { gte: todayStart }, status: 'NEW' } }),
        this.db.application.count({ where: { status: 'QUALIFIED' } }),
        this.db.application.count({ where: { status: 'IN_REVIEW' } }),
        this.db.application.count({
          where: { status: { in: ['NEW', 'QUALIFIED', 'IN_REVIEW', 'MEETING_SCHEDULED'] } },
        }),
        this.db.application.count({
          where: {
            status: { in: ['NEW', 'QUALIFIED', 'IN_REVIEW'] },
            slaFirstResponseAt: { not: null, lt: new Date() },
            firstResponseAt: null,
          },
        }),
      ]);

      responded = await this.db.application.findMany({
        where: { firstResponseAt: { not: null } },
        select: { createdAt: true, firstResponseAt: true },
        take: 500,
        orderBy: { firstResponseAt: 'desc' },
      });
    } catch (error) {
      if (!this.isMissingApplicationTable(error)) throw error;
    }

    const avgFirstResponseMinutes = responded.length
      ? Math.round(
          responded.reduce((acc, row) => {
            const created = new Date(row.createdAt).getTime();
            const first = row.firstResponseAt ? new Date(row.firstResponseAt).getTime() : created;
            return acc + Math.max(0, first - created);
          }, 0) /
            responded.length /
            60000,
        )
      : 0;

    return { newToday, qualified, inReview, totalOpen, avgFirstResponseMinutes, slaBreaches: breaches };
  }
}
