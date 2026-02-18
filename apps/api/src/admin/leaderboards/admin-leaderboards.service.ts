import { Injectable } from '@nestjs/common';
import { DealStatus, OfferStatus, Role } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

type DateRange = { from: Date; to: Date };

@Injectable()
export class AdminLeaderboardsService {
  constructor(private readonly prisma: PrismaService) {}

  private resolveDateRange(from?: string, to?: string): DateRange {
    const now = new Date();
    const safeTo = to ? new Date(to) : now;
    const parsedTo = Number.isNaN(safeTo.getTime()) ? now : safeTo;
    const safeFrom = from ? new Date(from) : new Date(parsedTo.getTime() - 30 * 24 * 60 * 60 * 1000);
    const parsedFrom = Number.isNaN(safeFrom.getTime()) ? new Date(parsedTo.getTime() - 30 * 24 * 60 * 60 * 1000) : safeFrom;
    return parsedFrom <= parsedTo ? { from: parsedFrom, to: parsedTo } : { from: parsedTo, to: parsedFrom };
  }

  private gmvWeight(gmv: number) {
    return Number((gmv / 100_000).toFixed(2));
  }

  async getLeaderboards(roleRaw?: string, from?: string, to?: string) {
    const role = String(roleRaw || '').toUpperCase();
    if (role === 'CONSULTANT') return this.getConsultantLeaderboard(from, to);
    if (role === 'BROKER') return this.getBrokerLeaderboard(from, to);
    return this.getHunterLeaderboard(from, to);
  }

  private async getHunterLeaderboard(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const users = await this.prisma.user.findMany({
      where: { role: Role.HUNTER },
      select: { id: true, name: true, email: true },
      orderBy: { createdAt: 'asc' },
    });

    const rows = await Promise.all(
      users.map(async (u) => {
        const [leadsCreated, qualified, portfolioConverted, dealsInfluenced] = await Promise.all([
          this.prisma.lead.count({
            where: { sourceUserId: u.id, createdAt: { gte: range.from, lte: range.to } },
          }),
          this.prisma.lead.count({
            where: {
              sourceUserId: u.id,
              createdAt: { gte: range.from, lte: range.to },
              status: {
                in: ['IN_PROGRESS', 'COMPLETED', 'ASSIGNED', 'OFFERED', 'WON'],
              },
            },
          }),
          this.prisma.deal.count({
            where: {
              lead: { sourceUserId: u.id },
              listingId: { not: null },
              updatedAt: { gte: range.from, lte: range.to },
            },
          }),
          this.prisma.deal.count({
            where: {
              lead: { sourceUserId: u.id },
              status: DealStatus.WON,
              updatedAt: { gte: range.from, lte: range.to },
            },
          }),
        ]);

        const spamPenalty = Math.max(0, leadsCreated - qualified) * 0.5;
        const score = qualified * 2 + portfolioConverted * 5 + dealsInfluenced * 3 - spamPenalty;
        return {
          userId: u.id,
          name: u.name || u.email,
          role: 'HUNTER',
          score: Number(score.toFixed(2)),
          breakdown: { leadsCreated, qualified, portfolioConverted, dealsInfluenced, spamPenalty },
        };
      }),
    );

    rows.sort((a, b) => b.score - a.score);
    return { role: 'HUNTER', from: range.from, to: range.to, rows };
  }

  private async getConsultantLeaderboard(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const users = await this.prisma.user.findMany({
      where: { role: Role.CONSULTANT },
      select: { id: true, name: true, email: true },
      orderBy: { createdAt: 'asc' },
    });

    const rows = await Promise.all(
      users.map(async (u) => {
        const [listings, dealsWon, revenueAgg, disputes] = await Promise.all([
          this.prisma.listing.count({
            where: { consultantId: u.id, createdAt: { gte: range.from, lte: range.to } },
          }),
          this.prisma.deal.count({
            where: { consultantId: u.id, status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to } },
          }),
          this.prisma.offer.aggregate({
            _sum: { amount: true },
            where: {
              consultantId: u.id,
              status: OfferStatus.ACCEPTED,
              OR: [{ decidedAt: { gte: range.from, lte: range.to } }, { updatedAt: { gte: range.from, lte: range.to } }],
            },
          }),
          this.prisma.commissionDispute.count({
            where: { againstUserId: u.id, createdAt: { gte: range.from, lte: range.to } },
          }),
        ]);

        const wonRows = await this.prisma.deal.findMany({
          where: { consultantId: u.id, status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to } },
          select: { createdAt: true, updatedAt: true },
          take: 200,
        });
        const avgCloseDays = wonRows.length
          ? Number(
              (
                wonRows.reduce(
                  (sum, d) => sum + Math.max(0, (new Date(d.updatedAt).getTime() - new Date(d.createdAt).getTime()) / 86400000),
                  0,
                ) / wonRows.length
              ).toFixed(2),
            )
          : 0;

        const gmv = Number(revenueAgg._sum.amount ?? 0);
        const disputePenalty = disputes * 2;
        const score = dealsWon * 8 + this.gmvWeight(gmv) + listings * 1 - disputePenalty;

        return {
          userId: u.id,
          name: u.name || u.email,
          role: 'CONSULTANT',
          score: Number(score.toFixed(2)),
          breakdown: { listings, dealsWon, gmv, avgCloseDays, disputePenalty },
        };
      }),
    );

    rows.sort((a, b) => b.score - a.score);
    return { role: 'CONSULTANT', from: range.from, to: range.to, rows };
  }

  private async getBrokerLeaderboard(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const users = await this.prisma.user.findMany({
      where: { role: Role.BROKER },
      select: { id: true, name: true, email: true },
      orderBy: { createdAt: 'asc' },
    });

    const rows = await Promise.all(
      users.map(async (u) => {
        const [dealsBrokered, gmvAgg, disputes, approvedSnapshots] = await Promise.all([
          this.prisma.deal.count({
            where: { status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to } },
          }),
          this.prisma.offer.aggregate({
            _sum: { amount: true },
            where: {
              status: OfferStatus.ACCEPTED,
              OR: [{ decidedAt: { gte: range.from, lte: range.to } }, { updatedAt: { gte: range.from, lte: range.to } }],
            },
          }),
          this.prisma.commissionDispute.count({
            where: { againstUserId: u.id, createdAt: { gte: range.from, lte: range.to } },
          }),
          this.prisma.commissionSnapshot.count({
            where: { approvedBy: u.id, approvedAt: { gte: range.from, lte: range.to } },
          }),
        ]);

        const gmv = Number(gmvAgg._sum.amount ?? 0);
        const disputeRatePenalty = disputes * 2;
        const score = dealsBrokered * 6 + this.gmvWeight(gmv) + approvedSnapshots * 2 - disputeRatePenalty;

        return {
          userId: u.id,
          name: u.name || u.email,
          role: 'BROKER',
          score: Number(score.toFixed(2)),
          breakdown: { dealsBrokered, gmv, approvedSnapshots, disputeRatePenalty },
        };
      }),
    );

    rows.sort((a, b) => b.score - a.score);
    return { role: 'BROKER', from: range.from, to: range.to, rows };
  }
}
