import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MatchingService } from './matching.service';
import { AuditEntityType, DealStatus, Prisma, Role } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { NetworkService } from '../network/network.service';
import { isNetworkCommissionsEnabled } from '../common/feature-flags/network-commissions';
import { isCommissionAllocationEnabled } from '../common/feature-flags/commission-allocation';
import { AllocationsService } from '../allocations/allocations.service';

@Injectable()
export class DealsService {
  constructor(
    private prisma: PrismaService,
    private matching: MatchingService,
    private audit: AuditService,
    private network: NetworkService,
    private allocations: AllocationsService,
  ) {}

  private normalizeCurrency(currency?: string) {
    const c = String(currency || 'TRY').trim().toUpperCase();
    return c || 'TRY';
  }

  private assertPositiveDecimal(v: Prisma.Decimal, field: string) {
    if (v.lte(0)) {
      throw new BadRequestException(`${field} must be > 0`);
    }
  }

  private assertNonNegativeDecimal(v: Prisma.Decimal, field: string) {
    if (v.lt(0)) {
      throw new BadRequestException(`${field} cannot be negative`);
    }
  }

  private assertRateSumIsOne(sum: Prisma.Decimal, field: string) {
    const tolerance = new Prisma.Decimal('0.000001');
    const delta = sum.sub(1).abs();
    if (delta.gt(tolerance)) {
      throw new BadRequestException(`${field} rates sum must be 1.0`);
    }
  }

  private toDecimal(v: Prisma.Decimal | number | string, field: string) {
    try {
      return new Prisma.Decimal(v);
    } catch {
      throw new BadRequestException(`${field} is invalid`);
    }
  }

  private async resolveCommissionRates(consultantId?: string | null) {
    const config = await this.prisma.commissionConfig.upsert({
      where: { id: 'default' },
      update: {},
      create: { id: 'default' },
    });

    const baseRate = this.toDecimal(config.baseRate, 'baseRate');
    this.assertPositiveDecimal(baseRate, 'baseRate');

    if (consultantId) {
      const profile = await this.prisma.consultantCommissionProfile.findUnique({
        where: { consultantId },
      });
      if (profile && profile.isActive) {
        const hunterRate = this.toDecimal(profile.hunterRate, 'hunterRate');
        const brokerRate = this.toDecimal(profile.brokerRate, 'brokerRate');
        const consultantRate = this.toDecimal(profile.consultantRate, 'consultantRate');
        const platformRate = this.toDecimal(profile.platformRate, 'platformRate');

        this.assertNonNegativeDecimal(hunterRate, 'hunterRate');
        this.assertNonNegativeDecimal(brokerRate, 'brokerRate');
        this.assertNonNegativeDecimal(consultantRate, 'consultantRate');
        this.assertNonNegativeDecimal(platformRate, 'platformRate');

        const sum = hunterRate.add(brokerRate).add(consultantRate).add(platformRate);
        this.assertRateSumIsOne(sum, 'consultant profile');

        return {
          source: 'CONSULTANT_PROFILE' as const,
          baseRate,
          hunterRate,
          brokerRate,
          consultantRate,
          platformRate,
        };
      }
    }

    const hunterSplit = Number(config.hunterSplit);
    const brokerSplit = Number(config.brokerSplit);
    const consultantSplit = Number(config.consultantSplit);
    const platformSplit = Number(config.platformSplit);
    const splitSum = hunterSplit + brokerSplit + consultantSplit + platformSplit;

    if ([hunterSplit, brokerSplit, consultantSplit, platformSplit].some((v) => v < 0)) {
      throw new BadRequestException('commission splits cannot be negative');
    }
    if (splitSum !== 100) {
      throw new BadRequestException('commission split total must be exactly 100');
    }

    return {
      source: 'GLOBAL_CONFIG' as const,
      baseRate,
      hunterRate: new Prisma.Decimal(hunterSplit).div(100),
      brokerRate: new Prisma.Decimal(brokerSplit).div(100),
      consultantRate: new Prisma.Decimal(consultantSplit).div(100),
      platformRate: new Prisma.Decimal(platformSplit).div(100),
    };
  }

  // ======================
  // READ
  // ======================

  async getById(id: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id },
      include: {
        lead: true,
        consultant: true,
      },
    });

    if (!deal) {
      throw new NotFoundException('Deal not found');
    }

    return deal;
  }

  async getByLeadId(leadId: string) {
    return this.prisma.deal.findFirst({
      where: { leadId },
      include: {
        lead: true,
        consultant: true,
      },
    });
  }

  async markWon(
    dealId: string,
    payload: { closingPrice: number | string; currency?: string },
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ) {
    const closingPrice = this.toDecimal(payload?.closingPrice ?? 0, 'closingPrice');
    this.assertPositiveDecimal(closingPrice, 'closingPrice');
    const currency = this.normalizeCurrency(payload?.currency);

    const deal = await this.prisma.deal.findUnique({
      where: { id: dealId },
      include: { commissionSnapshot: true },
    });
    if (!deal) throw new NotFoundException('Deal not found');
    if (deal.status === DealStatus.LOST) {
      throw new ConflictException('Deal is LOST and cannot be marked WON');
    }

    if (deal.commissionSnapshot) {
      let snapshot = deal.commissionSnapshot;
      const captured = await this.captureNetworkMetaIfEnabled(
        deal.id,
        snapshot.id,
        deal.consultantId ?? null,
        snapshot.networkMeta ?? null,
        actor,
      );
      if (captured) {
        snapshot = captured;
      }
      if (isCommissionAllocationEnabled()) {
        await this.allocations.generateAllocationsForSnapshot(snapshot.id, actor);
      }
      if (deal.status !== DealStatus.WON) {
        await this.prisma.deal.update({
          where: { id: dealId },
          data: { status: DealStatus.WON },
        });
        await this.audit.log({
          actorUserId: actor?.actorUserId ?? null,
          actorRole: actor?.actorRole ?? null,
          action: 'DEAL_STATUS_CHANGED',
          entityType: AuditEntityType.DEAL,
          entityId: dealId,
          beforeJson: { status: deal.status },
          afterJson: { status: DealStatus.WON },
          metaJson: { source: 'DEAL_WON_ENDPOINT' },
        });
      }
      return { deal: await this.getById(dealId), snapshot };
    }

    const rates = await this.resolveCommissionRates(deal.consultantId);
    const totalCommission = closingPrice.mul(rates.baseRate);
    const hunterAmount = totalCommission.mul(rates.hunterRate);
    const brokerAmount = totalCommission.mul(rates.brokerRate);
    const consultantAmount = totalCommission.mul(rates.consultantRate);
    const platformAmount = totalCommission.mul(rates.platformRate);

    let snapshot = await this.prisma.$transaction(async (tx) => {
      if (deal.status !== DealStatus.WON) {
        await tx.deal.update({
          where: { id: dealId },
          data: { status: DealStatus.WON },
        });
      }

      return tx.commissionSnapshot.upsert({
        where: { dealId },
        update: {},
        create: {
          dealId,
          closingPrice,
          currency,
          totalCommission,
          hunterAmount,
          brokerAmount,
          consultantAmount,
          platformAmount,
          rateUsedJson: {
            source: rates.source,
            baseRate: rates.baseRate.toString(),
            rates: {
              hunter: rates.hunterRate.toString(),
              broker: rates.brokerRate.toString(),
              consultant: rates.consultantRate.toString(),
              platform: rates.platformRate.toString(),
            },
            consultantId: deal.consultantId ?? null,
          },
        },
      });
    });

    const captured = await this.captureNetworkMetaIfEnabled(
      deal.id,
      snapshot.id,
      deal.consultantId ?? null,
      snapshot.networkMeta ?? null,
      actor,
    );
    if (captured) {
      snapshot = captured;
    }
    if (isCommissionAllocationEnabled()) {
      await this.allocations.generateAllocationsForSnapshot(snapshot.id, actor);
    }

    if (deal.status !== DealStatus.WON) {
      await this.audit.log({
        actorUserId: actor?.actorUserId ?? null,
        actorRole: actor?.actorRole ?? null,
        action: 'DEAL_STATUS_CHANGED',
        entityType: AuditEntityType.DEAL,
        entityId: dealId,
        beforeJson: { status: deal.status },
        afterJson: { status: DealStatus.WON },
        metaJson: { source: 'DEAL_WON_ENDPOINT' },
      });
    }
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? null,
      action: 'COMMISSION_SNAPSHOT_CREATED',
      entityType: AuditEntityType.DEAL,
      entityId: dealId,
      metaJson: {
        snapshotId: snapshot.id,
        totalCommission: snapshot.totalCommission.toString(),
        consultantAmount: snapshot.consultantAmount.toString(),
        brokerAmount: snapshot.brokerAmount.toString(),
        hunterAmount: snapshot.hunterAmount.toString(),
        platformAmount: snapshot.platformAmount.toString(),
      },
    });

    return { deal: await this.getById(dealId), snapshot };
  }

  private async captureNetworkMetaIfEnabled(
    dealId: string,
    snapshotId: string,
    consultantId: string | null,
    existingNetworkMeta: Prisma.JsonValue | null,
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ) {
    if (!isNetworkCommissionsEnabled()) {
      return null;
    }

    // Deterministic source user: deal consultant. If absent, metadata capture is skipped.
    if (!consultantId) {
      return null;
    }

    const consultant = await this.prisma.user.findUnique({
      where: { id: consultantId },
      select: { id: true, role: true, officeId: true },
    });
    if (!consultant) return null;

    const office = consultant.officeId
      ? await this.prisma.office.findUnique({
          where: { id: consultant.officeId },
          select: { id: true, regionId: true, overridePercent: true },
        })
      : null;

    const defaultPercent = 0;
    const effectiveSplitPercent = await this.network.getCommissionSplitByRole(consultant.role);
    const splitTrace: Prisma.JsonObject = {
      sourceUserId: consultant.id,
      sourceUserRole: consultant.role,
      effectiveSplitPercent: effectiveSplitPercent ?? null,
      defaultPercent,
      resolvedAt: new Date().toISOString(),
    };
    const officeTrace: Prisma.JsonObject = {
      sourceUserId: consultant.id,
      officeId: consultant.officeId ?? null,
      regionId: office?.regionId ?? null,
      overridePercent: office?.overridePercent ?? null,
      resolvedAt: new Date().toISOString(),
    };

    if (existingNetworkMeta && typeof existingNetworkMeta === 'object' && !Array.isArray(existingNetworkMeta)) {
      const asObj = existingNetworkMeta as Prisma.JsonObject;
      const hasSplitTrace = Object.prototype.hasOwnProperty.call(asObj, 'splitTrace');
      const hasOfficeTrace = Object.prototype.hasOwnProperty.call(asObj, 'officeTrace');
      if (hasSplitTrace && hasOfficeTrace) {
        return null;
      }
      // Existing networkMeta may be present from earlier capture; add missing traces once without extra audit.
      // Do not emit COMMISSION_SNAPSHOT_NETWORK_CAPTURED here to avoid audit spam.
      const mergedMeta: Prisma.JsonObject = {
        ...asObj,
        ...(hasSplitTrace ? {} : { splitTrace }),
        ...(hasOfficeTrace ? {} : { officeTrace }),
      };
      return this.prisma.commissionSnapshot.update({
        where: { id: snapshotId },
        data: { networkMeta: mergedMeta },
      });
    }

    const [pathRows, uplineRows, splitMap] = await Promise.all([
      this.network.getNetworkPath(consultantId),
      this.network.getUpline(consultantId, 10),
      this.network.getSplitMap(),
    ]);

    const networkMeta: Prisma.JsonObject = {
      userId: consultantId,
      path: pathRows.map((node) => node.id),
      upline: uplineRows.map((node) => ({
        id: node.id,
        role: node.role,
        parentId: node.parentId,
      })),
      splitMap,
      splitTrace,
      officeTrace,
      capturedAt: new Date().toISOString(),
    };

    const updated = await this.prisma.commissionSnapshot.update({
      where: { id: snapshotId },
      data: { networkMeta },
    });

    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? null,
      action: 'COMMISSION_SNAPSHOT_NETWORK_CAPTURED',
      entityType: AuditEntityType.COMMISSION,
      entityId: snapshotId,
      metaJson: {
        dealId,
        snapshotId,
        userId: consultantId,
      },
    });

    return updated;
  }

  async getCommissionSnapshot(
    dealId: string,
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ) {
    const deal = await this.prisma.deal.findUnique({
      where: { id: dealId },
      select: { id: true, consultantId: true },
    });
    if (!deal) throw new NotFoundException('Deal not found');

    const role = String(actor?.actorRole || '').toUpperCase();
    const actorUserId = String(actor?.actorUserId || '').trim();
    if (role === 'CONSULTANT' && deal.consultantId && deal.consultantId !== actorUserId) {
      throw new ForbiddenException('Forbidden resource');
    }
    if (!['ADMIN', 'BROKER', 'CONSULTANT'].includes(role)) {
      throw new ForbiddenException('Forbidden resource');
    }

    const snapshot = await this.prisma.commissionSnapshot.findUnique({
      where: { dealId },
    });
    if (!snapshot) throw new NotFoundException('Commission snapshot not found');
    return snapshot;
  }

  // ======================
  // CREATE / ENSURE
  // ======================

  async ensureForLead(leadId: string) {
    const existing = await this.prisma.deal.findFirst({
      where: { leadId },
    });

    if (existing) return existing;

    const created = await this.prisma.deal.create({
      data: {
        leadId,
        status: 'OPEN',
      },
    });
    await this.audit.log({
      action: 'DEAL_CREATED',
      entityType: AuditEntityType.DEAL,
      entityId: created.id,
      afterJson: { status: 'OPEN' },
      metaJson: { leadId, source: 'ENSURE_FOR_LEAD' },
    });
    return created;
  }

  // ======================
  // MATCHING
  // ======================

  async matchDeal(id: string) {
    // Backward-compatible guard: READY_FOR_MATCHING (legacy) or READY_FOR_LISTING (new)
    const deal0 = await this.prisma.deal.findUnique({ where: { id: id } });
    if (!deal0) throw new NotFoundException('Deal not found');
    if (deal0.status !== DealStatus.READY_FOR_MATCHING && deal0.status !== DealStatus.READY_FOR_LISTING) {
      throw new BadRequestException(`Deal not ready for match (status=${deal0.status})`);
    }

    const deal = await this.prisma.deal.findUnique({
      where: { id },
    });

    if (!deal) {
      throw new NotFoundException('Deal not found');
    }

    // idempotent
    if (deal.status === 'ASSIGNED') {
      return deal;
    }

    const consultant = await this.prisma.user.findFirst({
      where: { role: Role.CONSULTANT },
      orderBy: { createdAt: 'asc' },
    });

    if (!consultant) {
      throw new ConflictException('No consultant available');
    }

    const updated = await this.prisma.deal.update({
      where: { id },
      data: {
        consultantId: consultant.id,
        status: 'ASSIGNED',
      },
    });
    await this.audit.log({
      action: 'DEAL_ASSIGNED',
      entityType: AuditEntityType.DEAL,
      entityId: id,
      beforeJson: { consultantId: deal.consultantId },
      afterJson: { consultantId: consultant.id },
      metaJson: { source: 'MATCH_DEAL' },
    });
    await this.audit.log({
      action: 'DEAL_STATUS_CHANGED',
      entityType: AuditEntityType.DEAL,
      entityId: id,
      beforeJson: { status: deal.status },
      afterJson: { status: DealStatus.ASSIGNED },
    });
    return updated;
  }

  // ======================
  // STATE CONTROL (MINIMAL)
  // ======================

  async ensureStatusOpen(id: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id } });
    if (!deal) return null;

    if (deal.status === 'OPEN') return deal;

    return this.prisma.deal.update({
      where: { id },
      data: { status: 'OPEN' },
    });
  }

  async linkListing(dealId: string, listingId: string, actorUserId: string) {
    const actor = await this.prisma.user.findUnique({ where: { id: actorUserId }, select: { id: true, role: true } });
    if (!actor) throw new NotFoundException('User not found');
    if (actor.role !== Role.CONSULTANT && actor.role !== Role.ADMIN) {
      throw new BadRequestException('Only CONSULTANT/ADMIN can link listing');
    }

    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const listing = await this.prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) throw new NotFoundException('Listing not found');

    if (deal.consultantId && actor.role === Role.CONSULTANT && deal.consultantId !== actor.id) {
      throw new BadRequestException('Deal is assigned to another consultant');
    }
    if (actor.role === Role.CONSULTANT && listing.consultantId !== actor.id) {
      throw new BadRequestException('Listing does not belong to this consultant');
    }

    return this.prisma.deal.update({
      where: { id: dealId },
      data: { listingId },
    });
  }




  // Assign an OPEN deal to a consultant (used by inbox)
  async assignToMe(dealId: string, userId: string) {
    if (!userId) throw new BadRequestException('Missing x-user-id header');

    // Optional safety: only allow if currently unassigned + OPEN
    const deal = await (this.prisma as any).deal.findUnique({
      where: { id: dealId },
      select: { id: true, status: true, consultantId: true },
    });

    if (!deal) throw new NotFoundException('Deal not found');
    if (deal.status !== 'OPEN') throw new BadRequestException('Deal is not OPEN');
    if (deal.consultantId) throw new BadRequestException('Deal is already assigned');

    const updated = await (this.prisma as any).deal.update({
      where: { id: dealId },
      data: { consultantId: userId , status: 'ASSIGNED' },
      select: { id: true, status: true, consultantId: true, updatedAt: true, createdAt: true, leadId: true },
    });
    await this.audit.log({
      actorUserId: userId,
      actorRole: 'CONSULTANT',
      action: 'DEAL_ASSIGNED',
      entityType: AuditEntityType.DEAL,
      entityId: dealId,
      beforeJson: { consultantId: deal.consultantId },
      afterJson: { consultantId: userId },
      metaJson: { source: 'ASSIGN_TO_ME' },
    });
    await this.audit.log({
      actorUserId: userId,
      actorRole: 'CONSULTANT',
      action: 'DEAL_STATUS_CHANGED',
      entityType: AuditEntityType.DEAL,
      entityId: dealId,
      beforeJson: { status: deal.status },
      afterJson: { status: DealStatus.ASSIGNED },
    });
    return updated;
  }

  async assignByBroker(dealId: string, consultantId: string, actor?: { actorUserId?: string | null; actorRole?: string | null }) {
    if (!consultantId) throw new BadRequestException('consultantId is required');

    const deal = await this.prisma.deal.findUnique({
      where: { id: dealId },
      select: { id: true, status: true, consultantId: true },
    });
    if (!deal) throw new NotFoundException('Deal not found');
    if (deal.status === 'WON' || deal.status === 'LOST') {
      throw new BadRequestException(`Deal is closed (status=${deal.status})`);
    }

    const consultant = await this.prisma.user.findUnique({
      where: { id: consultantId },
      select: { id: true, role: true },
    });
    if (!consultant || consultant.role !== Role.CONSULTANT) {
      throw new BadRequestException('consultantId must belong to a CONSULTANT user');
    }

    const updated = await this.prisma.deal.update({
      where: { id: dealId },
      data: { consultantId: consultant.id, status: DealStatus.ASSIGNED },
      select: { id: true, status: true, consultantId: true, updatedAt: true, createdAt: true, leadId: true },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'BROKER',
      action: 'DEAL_ASSIGNED',
      entityType: AuditEntityType.DEAL,
      entityId: dealId,
      beforeJson: { consultantId: deal.consultantId },
      afterJson: { consultantId: consultant.id },
      metaJson: { source: 'BROKER_ASSIGN' },
    });
    if (deal.status !== DealStatus.ASSIGNED) {
      await this.audit.log({
        actorUserId: actor?.actorUserId ?? null,
        actorRole: actor?.actorRole ?? 'BROKER',
        action: 'DEAL_STATUS_CHANGED',
        entityType: AuditEntityType.DEAL,
        entityId: dealId,
        beforeJson: { status: deal.status },
        afterJson: { status: DealStatus.ASSIGNED },
      });
    }
    return updated;
  }


  // DEV helper: list user ids (avoid selecting unknown columns; only id)
  async devListUserIds(take: number = 20) {
    const t = Math.min(Math.max(take ?? 20, 0), 50);
    return await (this.prisma as any).user.findMany({
      take: t,
      select: { id: true },
    });
  }

  // ===== Consultant Inbox =====
  // Auto-generated from prisma/schema.prisma (model Deal fields)
  // Detected fields:
  // - statusField      : status
  // - consultantField  : consultantId
  // - createdField     : createdAt

  async listPendingInbox(paging: { take: number; skip: number }) {
    const take = Math.min(Math.max(paging?.take ?? 20, 0), 50);
    const skip = Math.max(paging?.skip ?? 0, 0);

    return await (this.prisma as any).deal.findMany({
      where: { status: 'OPEN', consultantId: null },
      orderBy: { createdAt: 'desc' },
      take,
      skip,
      select: { id: true, status: true, createdAt: true, updatedAt: true, city: true, district: true, type: true, rooms: true, consultantId: true, listingId: true, leadId: true },
    });
  }


  async listMineInbox(userId: string, paging: { take: number; skip: number }) {
    if (!userId) throw new BadRequestException('Missing x-user-id header');

    const take = Math.min(Math.max(paging?.take ?? 20, 0), 50);
    const skip = Math.max(paging?.skip ?? 0, 0);

    return await (this.prisma as any).deal.findMany({
      where: { status: { in: ['OPEN', 'ASSIGNED', 'READY_FOR_LISTING', 'READY_FOR_MATCHING'] }, consultantId: userId },
      orderBy: { createdAt: 'desc' },
      take,
      skip,
      select: { id: true, status: true, createdAt: true, updatedAt: true, city: true, district: true, type: true, rooms: true, consultantId: true, listingId: true, leadId: true },
    });
  }


}
