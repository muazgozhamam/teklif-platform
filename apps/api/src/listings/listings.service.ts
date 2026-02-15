import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditEntityType, DealStatus, ListingStatus } from '@prisma/client';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class ListingsService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

  async getById(id: string) {
    const listing = await this.prisma.listing.findUnique({ where: { id } });
    if (!listing) throw new NotFoundException('Listing not found');
    return listing;
  }

  async listAll() {
    return this.prisma.listing.findMany({ orderBy: { createdAt: 'desc' as any } });
  }

  async create(dto: any) {
    const data: any = {};
    if (dto?.title !== undefined) data.title = String(dto.title).trim() || 'İlan Taslağı';
    if (dto?.description !== undefined) data.description = (dto.description ?? '').trim() || null;
    if (dto?.price !== undefined) data.price = dto.price ?? null;
    if (dto?.currency !== undefined) data.currency = String(dto.currency ?? 'TRY').trim() || 'TRY';
    if (dto?.city !== undefined) data.city = (dto.city ?? '').trim() || null;
    if (dto?.district !== undefined) data.district = (dto.district ?? '').trim() || null;
    if (dto?.type !== undefined) data.type = (dto.type ?? '').trim() || null;
    if (dto?.rooms !== undefined) data.rooms = (dto.rooms ?? '').trim() || null;
    if (dto?.status !== undefined) data.status = dto.status as any;

    if (dto?.consultantId) {
      data.consultant = { connect: { id: String(dto.consultantId) } };
    }

    if (!data.title) {
      const t = [data.city, data.district, data.type, data.rooms].filter(Boolean).join(' - ');
      data.title = t || 'İlan Taslağı';
    }

    if (!(data as any).consultant && !(data as any).consultantId) {
      const u =
        (await this.prisma.user.findFirst({ where: { role: 'CONSULTANT' as any } })) ??
        (await this.prisma.user.findFirst());
      if (!u) {
        throw new BadRequestException('No consultant user found to attach to listing');
      }
      (data as any).consultant = { connect: { id: u.id } };
    }

    return this.prisma.listing.create({ data });
  }

  async update(id: string, dto: any) {
    const exists = await this.prisma.listing.findUnique({ where: { id } });
    if (!exists) throw new NotFoundException('Listing not found');

    const data: any = {};
    if (dto?.title !== undefined) data.title = String(dto.title).trim() || 'İlan Taslağı';
    if (dto?.description !== undefined) data.description = (dto.description ?? '').trim() || null;
    if (dto?.price !== undefined) data.price = dto.price ?? null;
    if (dto?.currency !== undefined) data.currency = String(dto.currency ?? 'TRY').trim() || 'TRY';
    if (dto?.city !== undefined) data.city = (dto.city ?? '').trim() || null;
    if (dto?.district !== undefined) data.district = (dto.district ?? '').trim() || null;
    if (dto?.type !== undefined) data.type = (dto.type ?? '').trim() || null;
    if (dto?.rooms !== undefined) data.rooms = (dto.rooms ?? '').trim() || null;
    if (dto?.status !== undefined) data.status = dto.status as any;

    if (dto?.consultantId !== undefined) {
      const cid = dto.consultantId ? String(dto.consultantId) : null;
      if (cid) data.consultant = { connect: { id: cid } };
    }

    if (
      dto?.title === undefined &&
      (dto?.city !== undefined || dto?.district !== undefined || dto?.type !== undefined || dto?.rooms !== undefined)
    ) {
      const city = data.city ?? exists.city ?? null;
      const district = data.district ?? exists.district ?? null;
      const type = data.type ?? exists.type ?? null;
      const rooms = data.rooms ?? exists.rooms ?? null;
      const t = [city, district, type, rooms].filter(Boolean).join(' - ');
      data.title = t || 'İlan Taslağı';
    }

    return this.prisma.listing.update({ where: { id }, data });
  }

  async getByDealId(dealId: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const listingId = (deal as any).listingId as string | null | undefined;
    if (!listingId) throw new NotFoundException('Listing not linked to this deal yet');

    const listing = await this.prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) throw new NotFoundException('Listing not found');
    return listing;
  }

  async upsertFromDealMeta(
    dealId: string,
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ): Promise<{ listing: any; created: boolean }> {
    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const consultantId = (deal as any).consultantId as string | null | undefined;
    if (!consultantId) throw new ConflictException('Deal is not assigned to a consultant yet');

    const _city = (deal as any).city ?? null;
    const _district = (deal as any).district ?? null;
    const _type = (deal as any).type ?? null;
    const _rooms = (deal as any).rooms ?? null;
    const _title = [_city, _district, _type, _rooms].filter(Boolean).join(' - ') || 'İlan Taslağı';

    const updateData: any = { city: _city, district: _district, type: _type, rooms: _rooms, title: _title };

    const listingId = (deal as any).listingId as string | null | undefined;

    if (listingId) {
      const updated = await this.prisma.listing.update({ where: { id: listingId }, data: updateData });
      const beforeStatus = deal.status;
      await this.prisma.deal.update({
        where: { id: dealId },
        data: { status: DealStatus.READY_FOR_LISTING },
      });
      if (beforeStatus !== DealStatus.READY_FOR_LISTING) {
        await this.audit.log({
          actorUserId: actor?.actorUserId ?? consultantId,
          actorRole: actor?.actorRole ?? 'CONSULTANT',
          action: 'DEAL_STATUS_CHANGED',
          entityType: AuditEntityType.DEAL,
          entityId: dealId,
          beforeJson: { status: beforeStatus },
          afterJson: { status: DealStatus.READY_FOR_LISTING },
        });
      }
      await this.audit.log({
        actorUserId: actor?.actorUserId ?? consultantId,
        actorRole: actor?.actorRole ?? 'CONSULTANT',
        action: 'LISTING_UPSERTED',
        entityType: AuditEntityType.LISTING,
        entityId: updated.id,
        afterJson: { listingId: updated.id },
        metaJson: { dealId, created: false },
      });
      return { listing: updated, created: false };
    }

    const created = await this.prisma.listing.create({
      data: {
        ...updateData,
        consultant: { connect: { id: consultantId } },
      },
    });

    await this.prisma.deal.update({
      where: { id: dealId },
      data: { listingId: created.id, status: DealStatus.READY_FOR_LISTING },
    });
    if (deal.status !== DealStatus.READY_FOR_LISTING) {
      await this.audit.log({
        actorUserId: actor?.actorUserId ?? consultantId,
        actorRole: actor?.actorRole ?? 'CONSULTANT',
        action: 'DEAL_STATUS_CHANGED',
        entityType: AuditEntityType.DEAL,
        entityId: dealId,
        beforeJson: { status: deal.status },
        afterJson: { status: DealStatus.READY_FOR_LISTING },
      });
    }
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? consultantId,
      actorRole: actor?.actorRole ?? 'CONSULTANT',
      action: 'LISTING_UPSERTED',
      entityType: AuditEntityType.LISTING,
      entityId: created.id,
      afterJson: { listingId: created.id },
      metaJson: { dealId, created: true },
    });
    return { listing: created, created: true };
  }

  async upsertFromDeal(dealId: string, actor?: { actorUserId?: string | null; actorRole?: string | null }) {
    const r = await this.upsertFromDealMeta(dealId, actor);
    return r.listing;
  }

  /**
   * Publish listing: DRAFT -> PUBLISHED
   * Also CLOSES related deal(s)
   */
  async publish(id: string, actor?: { actorUserId?: string | null; actorRole?: string | null }) {
    const beforeDeals = await this.prisma.deal.findMany({
      where: { listingId: id },
      select: { id: true, status: true },
    });
    const updated = await this.prisma.$transaction(async (tx) => {
      const listing = await tx.listing.findUnique({ where: { id } });
      if (!listing) throw new NotFoundException('Listing not found');

      const title = (listing as any).title ?? null;
      const price = (listing as any).price ?? null;

      if (!title || String(title).trim().length === 0) {
        throw new BadRequestException('Listing title is required before publish');
      }
      if (price === null || price === undefined) {
        throw new BadRequestException('Listing price is required before publish');
      }

      const updated = await tx.listing.update({
        where: { id },
        data: { status: ListingStatus.PUBLISHED },
      });

      const r = await tx.deal.updateMany({
        where: { listingId: id },
        data: { status: DealStatus.WON },
      });

      console.log('[publish] listing', id, 'closed deals:', r.count);

      return updated;
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? null,
      action: 'LISTING_PUBLISHED',
      entityType: AuditEntityType.LISTING,
      entityId: id,
      afterJson: { status: ListingStatus.PUBLISHED },
    });
    for (const d of beforeDeals) {
      if (d.status !== DealStatus.WON) {
        await this.audit.log({
          actorUserId: actor?.actorUserId ?? null,
          actorRole: actor?.actorRole ?? null,
          action: 'DEAL_STATUS_CHANGED',
          entityType: AuditEntityType.DEAL,
          entityId: d.id,
          beforeJson: { status: d.status },
          afterJson: { status: DealStatus.WON },
          metaJson: { source: 'LISTING_PUBLISH' },
        });
      }
    }
    return updated;
  }

  async markSold(id: string, actor?: { actorUserId?: string | null; actorRole?: string | null }) {
    const beforeDeals = await this.prisma.deal.findMany({
      where: { listingId: id },
      select: { id: true, status: true },
    });
    const updated = await this.prisma.$transaction(async (tx) => {
      const listing = await tx.listing.findUnique({ where: { id } });
      if (!listing) throw new NotFoundException('Listing not found');

      const updated = await tx.listing.update({
        where: { id },
        data: { status: ListingStatus.SOLD },
      });

      await tx.deal.updateMany({
        where: { listingId: id },
        data: { status: DealStatus.WON },
      });

      return updated;
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? null,
      action: 'LISTING_SOLD',
      entityType: AuditEntityType.LISTING,
      entityId: id,
      afterJson: { status: ListingStatus.SOLD },
    });
    for (const d of beforeDeals) {
      if (d.status !== DealStatus.WON) {
        await this.audit.log({
          actorUserId: actor?.actorUserId ?? null,
          actorRole: actor?.actorRole ?? null,
          action: 'DEAL_STATUS_CHANGED',
          entityType: AuditEntityType.DEAL,
          entityId: d.id,
          beforeJson: { status: d.status },
          afterJson: { status: DealStatus.WON },
          metaJson: { source: 'LISTING_SOLD' },
        });
      }
    }
    return updated;
  }

  async list(filters: any = {}) {
    const where: any = {};

    // Default feed behavior: if caller doesn't specify status, show only PUBLISHED
    if ((filters as any)?.status) {
      where.status = (filters as any).status;
    } else {
      where.status = 'PUBLISHED';
    }

    if ((filters as any)?.city) where.city = (filters as any).city;
    if ((filters as any)?.district) where.district = (filters as any).district;
    if ((filters as any)?.type) where.type = (filters as any).type;
    if ((filters as any)?.rooms) where.rooms = (filters as any).rooms;
    if ((filters as any)?.consultantId) where.consultantId = (filters as any).consultantId;

    // pagination: page/pageSize OR skip/take
    const pageSizeRaw = Number((filters as any)?.pageSize ?? (filters as any)?.take ?? 20);
    const pageRaw = Number((filters as any)?.page ?? 1);
    const pageSize = Number.isFinite(pageSizeRaw) && pageSizeRaw > 0 ? Math.min(pageSizeRaw, 100) : 20;
    const page = Number.isFinite(pageRaw) && pageRaw > 0 ? pageRaw : 1;

    let take = pageSize;
    let skip = (page - 1) * pageSize;

    const takeRaw = Number((filters as any)?.take);
    const skipRaw = Number((filters as any)?.skip);
    if (Number.isFinite(takeRaw) && takeRaw > 0) take = Math.min(takeRaw, 100);
    if (Number.isFinite(skipRaw) && skipRaw >= 0) skip = skipRaw;

    // ordering
    const sortByRaw = String((filters as any)?.sortBy ?? (filters as any)?.orderBy ?? 'createdAt');
    const dirRaw = String((filters as any)?.sortDir ?? (filters as any)?.direction ?? 'desc').toLowerCase();
    const direction = dirRaw === 'asc' ? 'asc' : 'desc';
    const allowed = new Set(['createdAt', 'updatedAt', 'price', 'title']);
    const sortBy = allowed.has(sortByRaw) ? sortByRaw : 'createdAt';

    const orderBy: any = {};
    orderBy[sortBy] = direction;

    const [items, total] = await Promise.all([
      this.prisma.listing.findMany({ where, orderBy, skip, take }),
      this.prisma.listing.count({ where }),
    ]);

    return { items, total, page, pageSize, take, skip };
  }

}
