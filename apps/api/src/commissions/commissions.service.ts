import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type ListQuery = {
  take?: number;
  skip?: number;
  from?: string;
  to?: string;
  status?: string;
  consultantId?: string;
  q?: string;
  officeId?: string;
  regionId?: string;
};

@Injectable()
export class CommissionsService {
  constructor(private readonly prisma: PrismaService) {}

  private parseDateOrThrow(raw?: string, fieldName = 'date') {
    if (!raw) return undefined;
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) {
      throw new BadRequestException(`${fieldName} is invalid`);
    }
    return d;
  }

  private parsePaging(take?: number, skip?: number) {
    const t = Math.min(Math.max(Number(take ?? 20) || 20, 1), 100);
    const s = Math.max(Number(skip ?? 0) || 0, 0);
    return { take: t, skip: s };
  }

  private amountToString(v: Prisma.Decimal | string | number | null | undefined) {
    if (v === null || v === undefined) return '0';
    if (typeof v === 'string') return v;
    if (typeof v === 'number') return String(v);
    return v.toString();
  }

  private buildCommonWhere(query: ListQuery) {
    const from = this.parseDateOrThrow(query.from, 'from');
    const to = this.parseDateOrThrow(query.to, 'to');
    const status = String(query.status ?? '').trim().toUpperCase();

    const where: Prisma.CommissionSnapshotWhereInput = {};
    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = from;
      if (to) where.createdAt.lte = to;
    }
    if (status) {
      where.deal = { ...(where.deal as object), status: status as never };
    }
    return where;
  }

  private mapRows(
    rows: Array<
      Prisma.CommissionSnapshotGetPayload<{
        include: { deal: { include: { consultant: { select: { id: true; email: true; name: true } } } } };
      }>
    >,
  ) {
    return rows.map((r) => ({
      dealId: r.dealId,
      listingId: r.deal?.listingId ?? null,
      createdAt: r.createdAt,
      closingPrice: this.amountToString(r.closingPrice),
      currency: r.currency,
      totalCommission: this.amountToString(r.totalCommission),
      consultantAmount: this.amountToString(r.consultantAmount),
      brokerAmount: this.amountToString(r.brokerAmount),
      hunterAmount: this.amountToString(r.hunterAmount),
      platformAmount: this.amountToString(r.platformAmount),
      consultant: r.deal?.consultant
        ? {
            id: r.deal.consultant.id,
            email: r.deal.consultant.email,
            name: r.deal.consultant.name ?? null,
          }
        : null,
    }));
  }

  async listMine(userId: string, query: ListQuery) {
    const { take, skip } = this.parsePaging(query.take, query.skip);
    const where = this.buildCommonWhere(query);
    where.deal = {
      ...(where.deal as object),
      consultantId: userId,
    };

    const [rows, total] = await Promise.all([
      this.prisma.commissionSnapshot.findMany({
        where,
        include: {
          deal: {
            include: {
              consultant: { select: { id: true, email: true, name: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take,
        skip,
      }),
      this.prisma.commissionSnapshot.count({ where }),
    ]);

    return { items: this.mapRows(rows), total, take, skip };
  }

  async listBroker(query: ListQuery) {
    const { take, skip } = this.parsePaging(query.take, query.skip);
    const where = this.buildCommonWhere(query);
    const consultantId = String(query.consultantId ?? '').trim();
    if (consultantId) {
      where.deal = {
        ...(where.deal as object),
        consultantId,
      };
    }

    const [rows, total] = await Promise.all([
      this.prisma.commissionSnapshot.findMany({
        where,
        include: {
          deal: {
            include: {
              consultant: { select: { id: true, email: true, name: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take,
        skip,
      }),
      this.prisma.commissionSnapshot.count({ where }),
    ]);

    return { items: this.mapRows(rows), total, take, skip };
  }

  async listAdmin(query: ListQuery) {
    const { take, skip } = this.parsePaging(query.take, query.skip);
    const where = this.buildCommonWhere(query);
    const q = String(query.q ?? '').trim();
    const officeId = String(query.officeId ?? '').trim();
    const regionId = String(query.regionId ?? '').trim();
    const andList = Array.isArray(where.AND)
      ? where.AND
      : where.AND
        ? [where.AND]
        : [];

    if (officeId) {
      // office scope: snapshots whose deal consultant belongs to officeId
      andList.push({ deal: { is: { consultant: { is: { officeId } } } } });
    }
    if (regionId) {
      // region scope: snapshots whose deal source lead belongs to regionId
      andList.push({ deal: { is: { lead: { is: { regionId } } } } });
    }

    if (q) {
      where.AND = [
        ...andList,
        {
          OR: [
            { dealId: { contains: q, mode: 'insensitive' } },
            { deal: { is: { listingId: { contains: q, mode: 'insensitive' } } } },
            { deal: { is: { consultant: { is: { email: { contains: q, mode: 'insensitive' } } } } } },
            { deal: { is: { consultant: { is: { name: { contains: q, mode: 'insensitive' } } } } } },
          ],
        },
      ];
    } else if (andList.length) {
      where.AND = andList;
    }

    const [rows, total] = await Promise.all([
      this.prisma.commissionSnapshot.findMany({
        where,
        include: {
          deal: {
            include: {
              consultant: { select: { id: true, email: true, name: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take,
        skip,
      }),
      this.prisma.commissionSnapshot.count({ where }),
    ]);

    return { items: this.mapRows(rows), total, take, skip };
  }
}
