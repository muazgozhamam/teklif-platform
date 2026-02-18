import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CommissionLedgerEntryType,
  CommissionLineStatus,
  CommissionRole,
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

type DateRange = { from: Date; to: Date };

const BP_DENOMINATOR = 10_000n;
const TRY_CURRENCY = 'TRY';

@Injectable()
export class CommissionService {
  constructor(private readonly prisma: PrismaService) {}

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

  private applyBasisPoints(amountMinor: bigint, bp: number): bigint {
    return (amountMinor * BigInt(bp)) / BP_DENOMINATOR;
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
        lead: { select: { id: true, sourceUserId: true } },
      },
    });

    if (!deal) throw new NotFoundException('Deal bulunamadı');
    if (deal.status !== DealStatus.WON) {
      throw new BadRequestException('Snapshot yalnızca WON deal için oluşturulabilir');
    }

    const listingPrice = deal.listing?.price ? BigInt(deal.listing.price) : null;
    if (!listingPrice) {
      throw new BadRequestException('Base Amount Missing: listing.price bulunamadı');
    }

    return {
      deal,
      baseAmountMinor: listingPrice,
      currency: deal.listing?.currency || TRY_CURRENCY,
      wonAt: deal.updatedAt,
    };
  }

  private buildAllocationPlan(input: {
    poolAmountMinor: bigint;
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
    const { poolAmountMinor, policy, participants } = input;

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

    const amounts = draft.map((row) => ({
      ...row,
      amountMinor: this.applyBasisPoints(poolAmountMinor, row.bp),
    }));

    const sum = amounts.reduce((acc, row) => acc + row.amountMinor, 0n);
    const remainder = poolAmountMinor - sum;
    if (remainder !== 0n && amounts.length > 0) {
      const target = amounts.find((row) => row.role === CommissionRole.CONSULTANT) || amounts[amounts.length - 1];
      target.amountMinor += remainder;
    }

    return amounts;
  }

  async createSnapshot(actorUserId: string, payload: CreateSnapshotDto) {
    const dealId = String(payload.dealId || '').trim();
    if (!dealId) throw new BadRequestException('dealId zorunlu');

    return this.prisma.$transaction(async (tx) => {
      const { deal, baseAmountMinor, currency, wonAt } = await this.resolveDealForSnapshot(tx, dealId);
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
        poolAmountMinor = (baseAmountMinor * rate + (BP_DENOMINATOR / 2n)) / BP_DENOMINATOR;
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

      return this.jsonSafe(updated);
    });
  }

  async reverseSnapshot(actorUserId: string, snapshotId: string, dto: ReverseSnapshotDto) {
    if (!dto.reason || !String(dto.reason).trim()) {
      throw new BadRequestException('Reverse reason zorunlu');
    }

    return this.prisma.$transaction(async (tx) => {
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

      let remainingToReverse = dto.amountMinor !== undefined ? this.asBigInt(dto.amountMinor, 'amountMinor') : null;

      for (const allocation of snapshot.allocations) {
        const paid = paidMap.get(allocation.id) || 0n;
        const outstanding = allocation.amountMinor - paid;
        if (outstanding <= 0n) continue;

        const reverseAmount = remainingToReverse === null ? outstanding : outstanding < remainingToReverse ? outstanding : remainingToReverse;
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
          data: { status: CommissionLineStatus.REVERSED },
        });

        if (remainingToReverse !== null) {
          remainingToReverse -= reverseAmount;
          if (remainingToReverse <= 0n) break;
        }
      }

      const updated = await tx.commissionSnapshot.update({
        where: { id: snapshot.id },
        data: { status: CommissionSnapshotStatus.REVERSED, reversedAt: new Date(), notes: dto.reason },
      });

      return this.jsonSafe(updated);
    });
  }

  async createPayout(actorUserId: string, dto: CreatePayoutDto) {
    if (!Array.isArray(dto.allocations) || dto.allocations.length === 0) {
      throw new BadRequestException('En az bir allocation gereklidir');
    }

    return this.prisma.$transaction(async (tx) => {
      const allocationIds = dto.allocations.map((a) => a.allocationId);
      const allocations = await tx.commissionAllocation.findMany({
        where: { id: { in: allocationIds } },
        include: { snapshot: true },
      });

      if (allocations.length !== allocationIds.length) {
        throw new BadRequestException('Bazı allocation kayıtları bulunamadı');
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

      return this.jsonSafe(payout);
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
