import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CommissionAuditAction,
  CommissionAuditEntityType,
  CommissionLedgerEntryType,
  CommissionLineStatus,
  CommissionRoundingRule,
  CommissionRole,
  CommissionDisputeType,
  CommissionDisputeStatus,
  CommissionSnapshotStatus,
  DealStatus,
  LedgerDirection,
  Prisma,
  Role,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSnapshotDto } from './dto/create-snapshot.dto';
import { ApproveSnapshotDto } from './dto/approve-snapshot.dto';
import { CreatePayoutDto } from './dto/create-payout.dto';
import { ReverseSnapshotDto } from './dto/reverse-snapshot.dto';
import { CreateDisputeDto } from './dto/create-dispute.dto';
import { UpdateDisputeStatusDto } from './dto/update-dispute-status.dto';
import { CreatePeriodLockDto } from './dto/create-period-lock.dto';
import { ReleasePeriodLockDto } from './dto/release-period-lock.dto';

type DateRange = { from: Date; to: Date };

const BP_DENOMINATOR = 10_000n;
const TRY_CURRENCY = 'TRY';
const BLOCKING_DISPUTE_STATUSES: CommissionDisputeStatus[] = [
  CommissionDisputeStatus.OPEN,
  CommissionDisputeStatus.UNDER_REVIEW,
  CommissionDisputeStatus.ESCALATED,
];

@Injectable()
export class CommissionService {
  constructor(private readonly prisma: PrismaService) {}

  private isMissingTableError(error: unknown, tableName: string): boolean {
    if (!(error instanceof Prisma.PrismaClientKnownRequestError)) return false;
    if (error.code !== 'P2021') return false;
    return String(error.message || '').includes(tableName);
  }

  private asBigInt(value: string | number | bigint | null | undefined, fieldName: string): bigint {
    if (value === null || value === undefined || value === '') {
      throw new BadRequestException(`${fieldName} zorunlu`);
    }
    try {
      return BigInt(value);
    } catch {
      throw new BadRequestException(`${fieldName} geçersiz`);
    }
  }

  private parseDateRange(from?: string, to?: string): DateRange {
    const now = new Date();
    const end = to ? new Date(to) : now;
    const start = from ? new Date(from) : new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException('Geçersiz tarih aralığı');
    }
    if (start > end) {
      throw new BadRequestException('from, to değerinden büyük olamaz');
    }
    return { from: start, to: end };
  }

  private jsonSafe<T>(input: T): T {
    return JSON.parse(
      JSON.stringify(input, (_, value) => (typeof value === 'bigint' ? value.toString() : value)),
    ) as T;
  }

  private divideWithRounding(
    numerator: bigint,
    denominator: bigint,
    rule: CommissionRoundingRule | string,
  ): bigint {
    if (denominator === 0n) return 0n;
    const quotient = numerator / denominator;
    const remainder = numerator % denominator;
    if (remainder === 0n) return quotient;

    const absRemainder = remainder < 0n ? -remainder : remainder;
    const absDenominator = denominator < 0n ? -denominator : denominator;
    const absQuotient = quotient < 0n ? -quotient : quotient;
    const isNegative = numerator < 0n;
    const twice = absRemainder * 2n;

    let roundUp = false;
    if (twice > absDenominator) {
      roundUp = true;
    } else if (twice === absDenominator) {
      if (String(rule || '') === 'BANKERS') {
        roundUp = absQuotient % 2n !== 0n;
      } else {
        roundUp = true;
      }
    }

    if (!roundUp) return quotient;
    return isNegative ? quotient - 1n : quotient + 1n;
  }

  private parseAmountMinor(raw: string | number | null | undefined): bigint | null {
    if (raw === null || raw === undefined) return null;
    if (typeof raw === 'number' && Number.isFinite(raw)) return BigInt(Math.trunc(raw));

    const cleaned = String(raw).replace(/[^\d.,-]/g, '').trim();
    if (!cleaned) return null;
    const normalized = cleaned.replace(/\./g, '').replace(',', '.');
    const parsed = Number(normalized);
    if (Number.isNaN(parsed) || !Number.isFinite(parsed)) return null;
    return BigInt(Math.round(parsed * 100));
  }

  private resolveBaseAmountFromLeadAnswers(
    answers: Array<{ key: string; answer: string }>,
  ): bigint | null {
    const priorityKeys = [
      'commissionBaseAmount',
      'commission_base_amount',
      'closeSummary.commissionBaseAmount',
      'close_summary_commission_base_amount',
      'salePrice',
      'sale_price',
      'price',
      'fiyat',
      'listingPrice',
      'listing_price',
    ];

    const lowered = new Map(
      answers.map((row) => [String(row.key || '').trim().toLowerCase(), String(row.answer || '').trim()]),
    );
    for (const key of priorityKeys) {
      const found = lowered.get(key.toLowerCase());
      const parsed = this.parseAmountMinor(found);
      if (parsed && parsed > 0n) return parsed;
    }
    return null;
  }

  private async resolveActivePolicy(tx: Prisma.TransactionClient, at: Date) {
    const existing = await tx.commissionPolicyVersion.findFirst({
      where: {
        isActive: true,
        effectiveFrom: { lte: at },
        OR: [{ effectiveTo: null }, { effectiveTo: { gte: at } }],
      },
      orderBy: { effectiveFrom: 'desc' },
    });

    if (existing) return existing;

    return tx.commissionPolicyVersion.create({
      data: {
        name: 'Default Policy',
        calcMethod: 'PERCENTAGE',
        commissionRateBasisPoints: 400,
        currency: TRY_CURRENCY,
        hunterPercentBasisPoints: 3000,
        consultantPercentBasisPoints: 5000,
        brokerPercentBasisPoints: 2000,
        systemPercentBasisPoints: 0,
        roundingRule: 'ROUND_HALF_UP',
        effectiveFrom: new Date('2026-01-01T00:00:00.000Z'),
        isActive: true,
      },
    });
  }

  private async resolveDealForSnapshot(tx: Prisma.TransactionClient, dealId: string) {
    const deal = await tx.deal.findUnique({
      where: { id: dealId },
      include: {
        listing: { select: { id: true, price: true, currency: true } },
        lead: {
          select: {
            id: true,
            sourceUserId: true,
            answers: { select: { key: true, answer: true } },
          },
        },
      },
    });

    if (!deal) throw new NotFoundException('Deal bulunamadı');
    if (deal.status !== DealStatus.WON) {
      throw new BadRequestException('Snapshot yalnızca WON deal için oluşturulabilir');
    }

    const fromCloseSummary = this.resolveBaseAmountFromLeadAnswers(deal.lead?.answers || []);
    const fromListing = deal.listing?.price ? BigInt(deal.listing.price) : null;
    const fromDeal = null;
    const resolvedBaseAmountMinor = fromCloseSummary || fromListing || fromDeal;
    if (!resolvedBaseAmountMinor || resolvedBaseAmountMinor <= 0n) {
      throw new BadRequestException(
        'Base Amount Missing: closeSummary.commissionBaseAmount / listing.price / deal.salePrice bulunamadı',
      );
    }

    return {
      deal,
      baseAmountMinor: resolvedBaseAmountMinor,
      currency: deal.listing?.currency || TRY_CURRENCY,
      wonAt: deal.updatedAt,
    };
  }

  private buildAllocationPlan(input: {
    poolAmountMinor: bigint;
    roundingRule: CommissionRoundingRule | string;
    policy: {
      hunterPercentBasisPoints: number;
      consultantPercentBasisPoints: number;
      brokerPercentBasisPoints: number;
      systemPercentBasisPoints: number;
    };
    participants: {
      hunterUserId: string | null;
      consultantUserId: string | null;
      brokerUserId: string | null;
    };
  }) {
    const { poolAmountMinor, policy, participants, roundingRule } = input;

    let hunterBp = policy.hunterPercentBasisPoints;
    let consultantBp = policy.consultantPercentBasisPoints;
    let brokerBp = policy.brokerPercentBasisPoints;
    let systemBp = policy.systemPercentBasisPoints;

    if (!participants.hunterUserId) {
      consultantBp += hunterBp;
      hunterBp = 0;
    }
    if (!participants.brokerUserId) {
      consultantBp += brokerBp;
      brokerBp = 0;
    }
    if (!participants.consultantUserId) {
      systemBp += consultantBp;
      consultantBp = 0;
    }

    const draft = [
      { role: CommissionRole.HUNTER, userId: participants.hunterUserId, bp: hunterBp },
      { role: CommissionRole.CONSULTANT, userId: participants.consultantUserId, bp: consultantBp },
      { role: CommissionRole.BROKER, userId: participants.brokerUserId, bp: brokerBp },
      { role: CommissionRole.SYSTEM, userId: null, bp: systemBp },
    ].filter((row) => row.bp > 0);

    const raw = draft.map((row) => {
      const numerator = poolAmountMinor * BigInt(row.bp);
      const floored = numerator / BP_DENOMINATOR;
      const remainder = numerator % BP_DENOMINATOR;
      return { ...row, amountMinor: floored, remainder };
    });

    const sum = raw.reduce((acc, row) => acc + row.amountMinor, 0n);
    let undistributed = poolAmountMinor - sum;
    if (undistributed > 0n && raw.length > 0) {
      const ranking = [...raw].sort((a, b) => {
        if (a.remainder === b.remainder) return a.role.localeCompare(b.role);
        return a.remainder > b.remainder ? -1 : 1;
      });
      let cursor = 0;
      while (undistributed > 0n) {
        ranking[cursor % ranking.length].amountMinor += 1n;
        undistributed -= 1n;
        cursor += 1;
      }
    } else if (undistributed < 0n && raw.length > 0) {
      const ranking = [...raw].sort((a, b) => {
        if (a.remainder === b.remainder) return b.role.localeCompare(a.role);
        return a.remainder < b.remainder ? -1 : 1;
      });
      let cursor = 0;
      while (undistributed < 0n) {
        const row = ranking[cursor % ranking.length];
        if (row.amountMinor > 0n) {
          row.amountMinor -= 1n;
          undistributed += 1n;
        }
        cursor += 1;
      }
    }

    const amounts = raw.map(({ role, userId, bp, amountMinor }) => ({
      role,
      userId,
      bp,
      amountMinor,
    }));

    const finalSum = amounts.reduce((acc, row) => acc + row.amountMinor, 0n);
    const finalRemainder = poolAmountMinor - finalSum;
    if (finalRemainder !== 0n && amounts.length > 0) {
      const target = amounts.find((row) => row.role === CommissionRole.SYSTEM) || amounts[amounts.length - 1];
      target.amountMinor += finalRemainder;
    }

    return amounts;
  }

  private async hasBlockingDispute(
    tx: Prisma.TransactionClient,
    dealId: string,
    snapshotId?: string,
  ): Promise<boolean> {
    const count = await tx.commissionDispute.count({
      where: {
        dealId,
        status: { in: BLOCKING_DISPUTE_STATUSES },
        ...(snapshotId ? { OR: [{ snapshotId: null }, { snapshotId }] } : {}),
      },
    });
    return count > 0;
  }

  private async assertPeriodNotLocked(
    tx: Prisma.TransactionClient,
    at: Date,
    actionName: string,
  ): Promise<void> {
    let lock: { periodFrom: Date; periodTo: Date } | null = null;
    try {
      lock = await tx.commissionPeriodLock.findFirst({
        where: {
          isActive: true,
          periodFrom: { lte: at },
          periodTo: { gte: at },
        },
        orderBy: { periodFrom: 'desc' },
        select: { periodFrom: true, periodTo: true },
      });
    } catch (error) {
      if (this.isMissingTableError(error, 'CommissionPeriodLock')) return;
      throw error;
    }

    if (lock) {
      throw new BadRequestException(
        `${actionName} engellendi: dönem kilidi aktif (${lock.periodFrom.toISOString()} - ${lock.periodTo.toISOString()})`,
      );
    }
  }

  private async writeAudit(
    tx: Prisma.TransactionClient,
    input: {
      action: CommissionAuditAction;
      entityType: CommissionAuditEntityType;
      entityId?: string | null;
      actorUserId?: string | null;
      payload?: Prisma.InputJsonValue;
    },
  ) {
    await tx.commissionAuditEvent.create({
      data: {
        action: input.action,
        entityType: input.entityType,
        entityId: input.entityId || null,
        actorUserId: input.actorUserId || null,
        payloadJson: input.payload ?? Prisma.JsonNull,
      },
    });
  }

  async createSnapshot(actorUserId: string, payload: CreateSnapshotDto) {
    const dealId = String(payload.dealId || '').trim();
    if (!dealId) throw new BadRequestException('dealId zorunlu');

    return this.prisma.$transaction(async (tx) => {
      const { deal, baseAmountMinor, currency, wonAt } = await this.resolveDealForSnapshot(tx, dealId);
      await this.assertPeriodNotLocked(tx, wonAt, 'Snapshot oluşturma');
      const policy = await this.resolveActivePolicy(tx, wonAt);

      const key = (payload.idempotencyKey || `${dealId}:${wonAt.toISOString()}`).trim();
      const existing = await tx.commissionSnapshot.findUnique({
        where: { idempotencyKey: key },
        include: { allocations: true, policyVersion: true },
      });
      if (existing) return this.jsonSafe(existing);

      let poolAmountMinor = 0n;
      if (policy.calcMethod === 'PERCENTAGE') {
        const rate = BigInt(policy.commissionRateBasisPoints ?? 0);
        poolAmountMinor = this.divideWithRounding(
          baseAmountMinor * rate,
          BP_DENOMINATOR,
          policy.roundingRule,
        );
      } else {
        poolAmountMinor = BigInt(policy.fixedCommissionMinor ?? 0);
      }

      if (poolAmountMinor <= 0n) {
        throw new BadRequestException('Komisyon havuzu hesaplanamadı');
      }

      const latest = await tx.commissionSnapshot.findFirst({
        where: { dealId },
        orderBy: { version: 'desc' },
        select: { version: true },
      });
      const version = (latest?.version ?? 0) + 1;

      const participants = {
        hunterUserId: deal.lead?.sourceUserId || null,
        consultantUserId: deal.consultantId || null,
        brokerUserId: null,
      };

      const plan = this.buildAllocationPlan({
        poolAmountMinor,
        roundingRule: policy.roundingRule,
        policy: {
          hunterPercentBasisPoints: policy.hunterPercentBasisPoints,
          consultantPercentBasisPoints: policy.consultantPercentBasisPoints,
          brokerPercentBasisPoints: policy.brokerPercentBasisPoints,
          systemPercentBasisPoints: policy.systemPercentBasisPoints,
        },
        participants,
      });

      const snapshot = await tx.commissionSnapshot.create({
        data: {
          dealId,
          version,
          idempotencyKey: key,
          status: CommissionSnapshotStatus.PENDING_APPROVAL,
          baseAmountMinor,
          poolAmountMinor,
          currency: currency || policy.currency || TRY_CURRENCY,
          policyVersionId: policy.id,
          policySnapshotJson: {
            id: policy.id,
            name: policy.name,
            calcMethod: policy.calcMethod,
            commissionRateBasisPoints: policy.commissionRateBasisPoints,
            fixedCommissionMinor: policy.fixedCommissionMinor?.toString() || null,
            splits: {
              hunter: policy.hunterPercentBasisPoints,
              consultant: policy.consultantPercentBasisPoints,
              broker: policy.brokerPercentBasisPoints,
              system: policy.systemPercentBasisPoints,
            },
          },
          createdBy: actorUserId,
        },
      });

      const allocations = await Promise.all(
        plan.map((row) =>
          tx.commissionAllocation.create({
            data: {
              snapshotId: snapshot.id,
              role: row.role,
              userId: row.userId,
              percentBasisPoints: row.bp,
              amountMinor: row.amountMinor,
              status: CommissionLineStatus.PENDING,
            },
          }),
        ),
      );

      await Promise.all(
        allocations.map((allocation) =>
          tx.commissionLedgerEntry.create({
            data: {
              snapshotId: snapshot.id,
              allocationId: allocation.id,
              dealId,
              entryType: CommissionLedgerEntryType.EARN,
              direction: LedgerDirection.CREDIT,
              amountMinor: allocation.amountMinor,
              currency: snapshot.currency,
              createdBy: actorUserId,
              memo: 'Snapshot created',
            },
          }),
        ),
      );

      await this.writeAudit(tx, {
        action: CommissionAuditAction.SNAPSHOT_CREATED,
        entityType: CommissionAuditEntityType.SNAPSHOT,
        entityId: snapshot.id,
        actorUserId,
        payload: {
          dealId,
          version,
          poolAmountMinor: snapshot.poolAmountMinor.toString(),
          allocationCount: allocations.length,
        },
      });

      return this.jsonSafe({ snapshot, allocations });
    });
  }

  async getPendingApprovals(from?: string, to?: string) {
    const { from: start, to: end } = this.parseDateRange(from, to);
    const rows = await this.prisma.commissionSnapshot.findMany({
      where: {
        status: CommissionSnapshotStatus.PENDING_APPROVAL,
        createdAt: { gte: start, lte: end },
      },
      include: {
        deal: { select: { id: true, city: true, district: true, type: true, rooms: true } },
        maker: { select: { id: true, name: true, email: true, role: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return this.jsonSafe(rows);
  }

  async approveSnapshot(actorUserId: string, actorRole: Role | string, snapshotId: string, dto: ApproveSnapshotDto) {
    const role = String(actorRole || '').toUpperCase();
    if (role !== 'ADMIN' && role !== 'BROKER') {
      throw new ForbiddenException('Bu işlem için yetkiniz yok');
    }

    return this.prisma.$transaction(async (tx) => {
      const snapshot = await tx.commissionSnapshot.findUnique({
        where: { id: snapshotId },
        include: { allocations: true },
      });
      if (!snapshot) throw new NotFoundException('Snapshot bulunamadı');
      if (snapshot.status !== CommissionSnapshotStatus.PENDING_APPROVAL) {
        throw new BadRequestException('Snapshot onay beklemiyor');
      }

      if (snapshot.createdBy === actorUserId && !dto.allowMakerCheckerOverride) {
        throw new ForbiddenException('Maker-checker kuralı: oluşturan kullanıcı onaylayamaz');
      }
      await this.assertPeriodNotLocked(tx, new Date(), 'Snapshot onayı');

      const blockedByDispute = await this.hasBlockingDispute(tx, snapshot.dealId, snapshot.id);
      if (blockedByDispute) {
        throw new BadRequestException('Açık dispute varken snapshot onaylanamaz');
      }

      const updated = await tx.commissionSnapshot.update({
        where: { id: snapshotId },
        data: {
          status: CommissionSnapshotStatus.APPROVED,
          approvedBy: actorUserId,
          approvedAt: new Date(),
          notes: dto.note || snapshot.notes,
        },
      });

      await tx.commissionAllocation.updateMany({
        where: { snapshotId: snapshot.id, status: CommissionLineStatus.PENDING },
        data: { status: CommissionLineStatus.APPROVED },
      });

      await this.writeAudit(tx, {
        action: CommissionAuditAction.SNAPSHOT_APPROVED,
        entityType: CommissionAuditEntityType.SNAPSHOT,
        entityId: snapshot.id,
        actorUserId,
        payload: { note: dto.note || null, actorRole: role },
      });

      return this.jsonSafe(updated);
    });
  }

  async reverseSnapshot(actorUserId: string, snapshotId: string, dto: ReverseSnapshotDto) {
    if (!dto.reason || !String(dto.reason).trim()) {
      throw new BadRequestException('Reverse reason zorunlu');
    }

    return this.prisma.$transaction(async (tx) => {
      await this.assertPeriodNotLocked(tx, new Date(), 'Reverse');
      const snapshot = await tx.commissionSnapshot.findUnique({
        where: { id: snapshotId },
        include: { allocations: true },
      });
      if (!snapshot) throw new NotFoundException('Snapshot bulunamadı');
      if (snapshot.status === CommissionSnapshotStatus.REVERSED) {
        return this.jsonSafe(snapshot);
      }

      const paidByAllocation = await tx.commissionPayoutAllocation.groupBy({
        by: ['allocationId'],
        where: { allocationId: { in: snapshot.allocations.map((a) => a.id) } },
        _sum: { amountMinor: true },
      });
      const paidMap = new Map(paidByAllocation.map((row) => [row.allocationId, BigInt(row._sum.amountMinor || 0)]));

      const reversedByAllocation = await tx.commissionLedgerEntry.groupBy({
        by: ['allocationId'],
        where: {
          allocationId: { in: snapshot.allocations.map((a) => a.id) },
          entryType: CommissionLedgerEntryType.REVERSAL,
          direction: LedgerDirection.DEBIT,
        },
        _sum: { amountMinor: true },
      });
      const reversedMap = new Map(
        reversedByAllocation
          .filter((row): row is typeof row & { allocationId: string } => Boolean(row.allocationId))
          .map((row) => [row.allocationId, BigInt(row._sum.amountMinor || 0)]),
      );

      let remainingToReverse = dto.amountMinor !== undefined ? this.asBigInt(dto.amountMinor, 'amountMinor') : null;
      let reversedTotal = 0n;
      let totalReversible = 0n;

      for (const allocation of snapshot.allocations) {
        const reversedAlready = reversedMap.get(allocation.id) || 0n;
        const reversible = allocation.amountMinor - reversedAlready;
        if (reversible > 0n) totalReversible += reversible;
      }

      for (const allocation of snapshot.allocations) {
        const reversedAlready = reversedMap.get(allocation.id) || 0n;
        const reversible = allocation.amountMinor - reversedAlready;
        if (reversible <= 0n) continue;

        const reverseAmount =
          remainingToReverse === null ? reversible : reversible < remainingToReverse ? reversible : remainingToReverse;
        if (reverseAmount <= 0n) continue;

        await tx.commissionLedgerEntry.create({
          data: {
            snapshotId: snapshot.id,
            allocationId: allocation.id,
            dealId: snapshot.dealId,
            entryType: CommissionLedgerEntryType.REVERSAL,
            direction: LedgerDirection.DEBIT,
            amountMinor: reverseAmount,
            currency: snapshot.currency,
            createdBy: actorUserId,
            memo: `Reverse: ${dto.reason}`,
          },
        });

        await tx.commissionAllocation.update({
          where: { id: allocation.id },
          data: {
            status:
              reversedAlready + reverseAmount >= allocation.amountMinor
                ? CommissionLineStatus.REVERSED
                : CommissionLineStatus.PARTIAL,
          },
        });

        reversedTotal += reverseAmount;

        if (remainingToReverse !== null) {
          remainingToReverse -= reverseAmount;
          if (remainingToReverse <= 0n) break;
        }
      }

      if (reversedTotal <= 0n) {
        throw new BadRequestException('Reverse edilebilir bakiye bulunamadı');
      }

      const isFullReverse = reversedTotal >= totalReversible;

      const updated = await tx.commissionSnapshot.update({
        where: { id: snapshot.id },
        data: {
          status: isFullReverse ? CommissionSnapshotStatus.REVERSED : snapshot.status,
          reversedAt: isFullReverse ? new Date() : snapshot.reversedAt,
          notes: dto.reason,
        },
      });

      await this.writeAudit(tx, {
        action: CommissionAuditAction.SNAPSHOT_REVERSED,
        entityType: CommissionAuditEntityType.SNAPSHOT,
        entityId: snapshot.id,
        actorUserId,
        payload: {
          reason: dto.reason,
          reversedTotal: reversedTotal.toString(),
          isFullReverse,
        },
      });

      return this.jsonSafe(updated);
    });
  }

  async listDisputes(status?: string) {
    const normalized = status ? String(status).toUpperCase() : undefined;
    const where = normalized ? { status: normalized as CommissionDisputeStatus } : undefined;

    const rows = await this.prisma.commissionDispute.findMany({
      where,
      include: {
        deal: { select: { id: true, city: true, district: true, type: true, rooms: true } },
        snapshot: { select: { id: true, status: true, version: true } },
        opener: { select: { id: true, name: true, email: true, role: true } },
        resolver: { select: { id: true, name: true, email: true, role: true } },
        againstUser: { select: { id: true, name: true, email: true, role: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return this.jsonSafe(rows);
  }

  async createDispute(actorUserId: string, dto: CreateDisputeDto) {
    const dealId = String(dto.dealId || '').trim();
    if (!dealId) throw new BadRequestException('dealId zorunlu');

    const type = String(dto.type || 'OTHER').toUpperCase() as CommissionDisputeType;
    const allowedTypes = new Set<CommissionDisputeType>(['ATTRIBUTION', 'AMOUNT', 'ROLE', 'OTHER']);
    if (!allowedTypes.has(type)) throw new BadRequestException('Geçersiz dispute type');

    const slaDays = dto.slaDays && Number.isFinite(Number(dto.slaDays)) ? Math.max(1, Number(dto.slaDays)) : 3;
    const slaDueAt = new Date(Date.now() + slaDays * 24 * 60 * 60 * 1000);

    const deal = await this.prisma.deal.findUnique({ where: { id: dealId }, select: { id: true } });
    if (!deal) throw new NotFoundException('Deal bulunamadı');

    let snapshotId: string | null = null;
    if (dto.snapshotId) {
      const snapshot = await this.prisma.commissionSnapshot.findUnique({
        where: { id: String(dto.snapshotId) },
        select: { id: true, dealId: true },
      });
      if (!snapshot) throw new NotFoundException('Snapshot bulunamadı');
      if (snapshot.dealId !== dealId) throw new BadRequestException('snapshotId, dealId ile eşleşmiyor');
      snapshotId = snapshot.id;
    }

    const created = await this.prisma.commissionDispute.create({
      data: {
        dealId,
        snapshotId,
        openedBy: actorUserId,
        againstUserId: dto.againstUserId ? String(dto.againstUserId) : null,
        type,
        status: CommissionDisputeStatus.OPEN,
        slaDueAt,
        resolutionNote: dto.note || null,
        evidenceMetaJson: dto.evidenceMetaJson
          ? (dto.evidenceMetaJson as Prisma.InputJsonValue)
          : Prisma.JsonNull,
      },
    });

    await this.prisma.$transaction(async (tx) => {
      await this.writeAudit(tx, {
        action: CommissionAuditAction.DISPUTE_CREATED,
        entityType: CommissionAuditEntityType.DISPUTE,
        entityId: created.id,
        actorUserId,
        payload: {
          dealId: created.dealId,
          snapshotId: created.snapshotId,
          type: created.type,
          status: created.status,
        },
      });
    });

    return this.jsonSafe(created);
  }

  async updateDisputeStatus(actorUserId: string, disputeId: string, dto: UpdateDisputeStatusDto) {
    const status = String(dto.status || '').toUpperCase() as CommissionDisputeStatus;
    const allowed = new Set<CommissionDisputeStatus>([
      CommissionDisputeStatus.UNDER_REVIEW,
      CommissionDisputeStatus.ESCALATED,
      CommissionDisputeStatus.RESOLVED_APPROVED,
      CommissionDisputeStatus.RESOLVED_REJECTED,
    ]);
    if (!allowed.has(status)) throw new BadRequestException('Geçersiz dispute status');

    const current = await this.prisma.commissionDispute.findUnique({ where: { id: disputeId } });
    if (!current) throw new NotFoundException('Dispute bulunamadı');

    const isResolved =
      status === CommissionDisputeStatus.RESOLVED_APPROVED || status === CommissionDisputeStatus.RESOLVED_REJECTED;

    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.commissionDispute.update({
        where: { id: disputeId },
        data: {
          status,
          resolvedAt: isResolved ? new Date() : null,
          resolvedBy: isResolved ? actorUserId : null,
          resolutionNote: dto.note || current.resolutionNote || null,
        },
      });
      await this.writeAudit(tx, {
        action: CommissionAuditAction.DISPUTE_STATUS_CHANGED,
        entityType: CommissionAuditEntityType.DISPUTE,
        entityId: row.id,
        actorUserId,
        payload: { previous: current.status, next: row.status, note: dto.note || null },
      });
      return row;
    });

    return this.jsonSafe(updated);
  }

  async createPayout(actorUserId: string, dto: CreatePayoutDto) {
    if (!Array.isArray(dto.allocations) || dto.allocations.length === 0) {
      throw new BadRequestException('En az bir allocation gereklidir');
    }

    return this.prisma.$transaction(async (tx) => {
      await this.assertPeriodNotLocked(tx, new Date(dto.paidAt), 'Payout');
      const allocationIds = dto.allocations.map((a) => a.allocationId);
      const allocations = await tx.commissionAllocation.findMany({
        where: { id: { in: allocationIds } },
        include: { snapshot: true },
      });

      if (allocations.length !== allocationIds.length) {
        throw new BadRequestException('Bazı allocation kayıtları bulunamadı');
      }

      const uniqueDealSnapshot = new Set(allocations.map((a) => `${a.snapshot.dealId}:${a.snapshot.id}`));
      for (const key of uniqueDealSnapshot) {
        const [dealId, snapId] = key.split(':');
        const blockedByDispute = await this.hasBlockingDispute(tx, dealId, snapId);
        if (blockedByDispute) {
          throw new BadRequestException(`Açık dispute varken payout yapılamaz (deal=${dealId})`);
        }
      }

      const alreadyPaid = await tx.commissionPayoutAllocation.groupBy({
        by: ['allocationId'],
        where: { allocationId: { in: allocationIds } },
        _sum: { amountMinor: true },
      });
      const paidMap = new Map(alreadyPaid.map((row) => [row.allocationId, BigInt(row._sum.amountMinor || 0)]));

      let total = 0n;
      const normalized = dto.allocations.map((input) => {
        const allocation = allocations.find((a) => a.id === input.allocationId)!;
        if (allocation.status !== CommissionLineStatus.APPROVED && allocation.status !== CommissionLineStatus.PARTIAL) {
          throw new BadRequestException(`Allocation ödemeye uygun değil: ${allocation.id}`);
        }
        const requested = this.asBigInt(input.amountMinor, 'allocation.amountMinor');
        if (requested <= 0n) throw new BadRequestException('Ödeme tutarı pozitif olmalıdır');

        const paid = paidMap.get(allocation.id) || 0n;
        const remaining = allocation.amountMinor - paid;

        if (requested > remaining && !dto.adminOverride) {
          throw new BadRequestException(`Allocation için fazla ödeme: ${allocation.id}`);
        }

        total += requested;
        return { allocation, requested, remaining };
      });

      const payout = await tx.commissionPayout.create({
        data: {
          paidAt: new Date(dto.paidAt),
          method: dto.method,
          referenceNo: dto.referenceNo,
          totalAmountMinor: total,
          currency: dto.currency || TRY_CURRENCY,
          createdBy: actorUserId,
        },
      });

      for (const row of normalized) {
        await tx.commissionPayoutAllocation.create({
          data: {
            payoutId: payout.id,
            allocationId: row.allocation.id,
            amountMinor: row.requested,
          },
        });

        await tx.commissionLedgerEntry.create({
          data: {
            snapshotId: row.allocation.snapshotId,
            allocationId: row.allocation.id,
            dealId: row.allocation.snapshot.dealId,
            entryType: CommissionLedgerEntryType.PAYOUT,
            direction: LedgerDirection.DEBIT,
            amountMinor: row.requested,
            currency: payout.currency,
            createdBy: actorUserId,
            referenceId: payout.id,
            memo: `Payout ${dto.method}`,
          },
        });

        const paidAfter = (paidMap.get(row.allocation.id) || 0n) + row.requested;
        const nextStatus =
          paidAfter >= row.allocation.amountMinor ? CommissionLineStatus.PAID : CommissionLineStatus.PARTIAL;

        await tx.commissionAllocation.update({
          where: { id: row.allocation.id },
          data: { status: nextStatus },
        });
      }

      await this.writeAudit(tx, {
        action: CommissionAuditAction.PAYOUT_CREATED,
        entityType: CommissionAuditEntityType.PAYOUT,
        entityId: payout.id,
        actorUserId,
        payload: {
          totalAmountMinor: payout.totalAmountMinor.toString(),
          method: payout.method,
          allocationCount: normalized.length,
        },
      });

      return this.jsonSafe(payout);
    });
  }

  async listPeriodLocks() {
    try {
      const rows = await this.prisma.commissionPeriodLock.findMany({
        include: {
          creator: { select: { id: true, name: true, email: true, role: true } },
          unlocker: { select: { id: true, name: true, email: true, role: true } },
        },
        orderBy: { createdAt: 'desc' },
      });
      return this.jsonSafe(rows);
    } catch (error) {
      if (this.isMissingTableError(error, 'CommissionPeriodLock')) return [];
      throw error;
    }
  }

  async createPeriodLock(actorUserId: string, dto: CreatePeriodLockDto) {
    const periodFrom = new Date(dto.periodFrom);
    const periodTo = new Date(dto.periodTo);
    if (Number.isNaN(periodFrom.getTime()) || Number.isNaN(periodTo.getTime())) {
      throw new BadRequestException('Geçersiz periodFrom/periodTo');
    }
    if (periodFrom > periodTo) {
      throw new BadRequestException('periodFrom, periodTo değerinden büyük olamaz');
    }
    if (!dto.reason || !dto.reason.trim()) {
      throw new BadRequestException('reason zorunlu');
    }

    try {
      return await this.prisma.$transaction(async (tx) => {
        const created = await tx.commissionPeriodLock.create({
          data: {
            periodFrom,
            periodTo,
            reason: dto.reason.trim(),
            createdBy: actorUserId,
          },
        });
        await this.writeAudit(tx, {
          action: CommissionAuditAction.PERIOD_LOCK_CREATED,
          entityType: CommissionAuditEntityType.PERIOD_LOCK,
          entityId: created.id,
          actorUserId,
          payload: { periodFrom: created.periodFrom.toISOString(), periodTo: created.periodTo.toISOString() },
        });
        return created;
      });
    } catch (error) {
      if (this.isMissingTableError(error, 'CommissionPeriodLock')) {
        throw new BadRequestException('CommissionPeriodLock tablosu eksik. Lütfen stage/prod migration çalıştırın.');
      }
      throw error;
    }
  }

  async releasePeriodLock(actorUserId: string, lockId: string, dto: ReleasePeriodLockDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        const lock = await tx.commissionPeriodLock.findUnique({ where: { id: lockId } });
        if (!lock) throw new NotFoundException('Period lock bulunamadı');
        if (!lock.isActive) return lock;

        const released = await tx.commissionPeriodLock.update({
          where: { id: lockId },
          data: {
            isActive: false,
            unlockedBy: actorUserId,
            unlockedAt: new Date(),
            reason: dto.reason?.trim() ? `${lock.reason} | release: ${dto.reason.trim()}` : lock.reason,
          },
        });
        await this.writeAudit(tx, {
          action: CommissionAuditAction.PERIOD_LOCK_RELEASED,
          entityType: CommissionAuditEntityType.PERIOD_LOCK,
          entityId: released.id,
          actorUserId,
          payload: { unlockedAt: released.unlockedAt?.toISOString() || null },
        });
        return released;
      });
    } catch (error) {
      if (this.isMissingTableError(error, 'CommissionPeriodLock')) {
        throw new BadRequestException('CommissionPeriodLock tablosu eksik. Lütfen stage/prod migration çalıştırın.');
      }
      throw error;
    }
  }

  async escalateOverdueDisputes(actorUserId: string) {
    const now = new Date();
    const rows = await this.prisma.commissionDispute.findMany({
      where: {
        status: { in: [CommissionDisputeStatus.OPEN, CommissionDisputeStatus.UNDER_REVIEW] },
        slaDueAt: { lt: now },
      },
      select: { id: true, status: true },
    });

    if (rows.length === 0) return { escalated: 0 };

    return this.prisma.$transaction(async (tx) => {
      let escalated = 0;
      for (const row of rows) {
        const updated = await tx.commissionDispute.update({
          where: { id: row.id },
          data: {
            status: CommissionDisputeStatus.ESCALATED,
            resolutionNote: 'SLA overdue auto-escalation',
          },
        });
        escalated += 1;
        await this.writeAudit(tx, {
          action: CommissionAuditAction.DISPUTE_ESCALATED,
          entityType: CommissionAuditEntityType.DISPUTE,
          entityId: updated.id,
          actorUserId,
          payload: { previous: row.status, next: updated.status, reason: 'sla_overdue' },
        });
      }
      return { escalated };
    });
  }

  async getOverview(from?: string, to?: string) {
    const { from: start, to: end } = this.parseDateRange(from, to);

    const [earnedAgg, paidAgg, reversedAgg, pendingCount] = await Promise.all([
      this.prisma.commissionLedgerEntry.aggregate({
        where: {
          entryType: CommissionLedgerEntryType.EARN,
          direction: LedgerDirection.CREDIT,
          occurredAt: { gte: start, lte: end },
        },
        _sum: { amountMinor: true },
      }),
      this.prisma.commissionLedgerEntry.aggregate({
        where: {
          entryType: CommissionLedgerEntryType.PAYOUT,
          direction: LedgerDirection.DEBIT,
          occurredAt: { gte: start, lte: end },
        },
        _sum: { amountMinor: true },
      }),
      this.prisma.commissionLedgerEntry.aggregate({
        where: {
          entryType: CommissionLedgerEntryType.REVERSAL,
          direction: LedgerDirection.DEBIT,
          occurredAt: { gte: start, lte: end },
        },
        _sum: { amountMinor: true },
      }),
      this.prisma.commissionSnapshot.count({
        where: {
          status: CommissionSnapshotStatus.PENDING_APPROVAL,
          createdAt: { gte: start, lte: end },
        },
      }),
    ]);

    const earned = BigInt(earnedAgg._sum.amountMinor || 0);
    const paid = BigInt(paidAgg._sum.amountMinor || 0);
    const reversed = BigInt(reversedAgg._sum.amountMinor || 0);
    const outstanding = earned - paid - reversed;

    return this.jsonSafe({
      totalEarnedMinor: earned,
      totalPaidMinor: paid,
      totalReversedMinor: reversed,
      payableOutstandingMinor: outstanding,
      pendingApprovalCount: pendingCount,
    });
  }

  async getDealDetail(dealId: string) {
    const snapshots = await this.prisma.commissionSnapshot.findMany({
      where: { dealId },
      include: {
        allocations: { include: { user: { select: { id: true, name: true, email: true, role: true } } } },
        maker: { select: { id: true, name: true, email: true } },
        checker: { select: { id: true, name: true, email: true } },
      },
      orderBy: { version: 'desc' },
    });

    const ledger = await this.prisma.commissionLedgerEntry.findMany({
      where: { dealId },
      orderBy: { occurredAt: 'desc' },
    });

    const allocationIds = snapshots.flatMap((s) => s.allocations.map((a) => a.id));
    const payoutLinks = allocationIds.length
      ? await this.prisma.commissionPayoutAllocation.findMany({
          where: { allocationId: { in: allocationIds } },
          include: { payout: true },
          orderBy: { payout: { paidAt: 'desc' } },
        })
      : [];

    return this.jsonSafe({ snapshots, ledger, payoutLinks });
  }

  async getMyCommission(userId: string, role: 'CONSULTANT' | 'HUNTER') {
    const rows = await this.prisma.commissionAllocation.findMany({
      where: {
        userId,
        role,
      },
      include: {
        snapshot: { select: { id: true, dealId: true, status: true, createdAt: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const allocationIds = rows.map((r) => r.id);
    const paid = allocationIds.length
      ? await this.prisma.commissionPayoutAllocation.groupBy({
          by: ['allocationId'],
          where: { allocationId: { in: allocationIds } },
          _sum: { amountMinor: true },
        })
      : [];
    const paidMap = new Map(paid.map((x) => [x.allocationId, BigInt(x._sum.amountMinor || 0)]));

    const items = rows.map((row) => {
      const paidMinor = paidMap.get(row.id) || 0n;
      const outstandingMinor = row.amountMinor - paidMinor;
      return {
        allocationId: row.id,
        dealId: row.snapshot.dealId,
        snapshotId: row.snapshotId,
        snapshotStatus: row.snapshot.status,
        amountMinor: row.amountMinor,
        paidMinor,
        outstandingMinor,
        status: row.status,
        createdAt: row.createdAt,
      };
    });

    const earnedMinor = items.reduce((acc, row) => acc + row.amountMinor, 0n);
    const paidMinor = items.reduce((acc, row) => acc + row.paidMinor, 0n);
    const outstandingMinor = items.reduce((acc, row) => acc + row.outstandingMinor, 0n);

    return this.jsonSafe({ earnedMinor, paidMinor, outstandingMinor, items });
  }
}
