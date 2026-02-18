import { Injectable } from '@nestjs/common';
import { DealStatus, OfferStatus, Role } from '@prisma/client';
import type { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

type DateRange = { from: Date; to: Date };

@Injectable()
export class AdminPerformanceService {
  constructor(private readonly prisma: PrismaService) {}

  resolveDateRange(from?: string, to?: string): DateRange {
    const now = new Date();
    const parsedTo = to ? new Date(to) : now;
    const safeTo = Number.isNaN(parsedTo.getTime()) ? now : parsedTo;

    const parsedFrom = from ? new Date(from) : new Date(safeTo.getTime() - 30 * 24 * 60 * 60 * 1000);
    const safeFrom = Number.isNaN(parsedFrom.getTime()) ? new Date(safeTo.getTime() - 30 * 24 * 60 * 60 * 1000) : parsedFrom;

    return safeFrom <= safeTo ? { from: safeFrom, to: safeTo } : { from: safeTo, to: safeFrom };
  }

  private referralWhere(range: DateRange): Prisma.LeadWhereInput {
    return {
      createdAt: { gte: range.from, lte: range.to },
      OR: [{ sourceUserId: { not: null } }, { sourceRole: { in: ['HUNTER', 'PARTNER'] } }],
    };
  }

  private async getRevenueSum(range: DateRange) {
    const revenueAgg = await this.prisma.offer.aggregate({
      _sum: { amount: true },
      where: {
        status: OfferStatus.ACCEPTED,
        OR: [
          { decidedAt: { gte: range.from, lte: range.to } },
          { updatedAt: { gte: range.from, lte: range.to } },
        ],
      },
    });
    return Number(revenueAgg._sum.amount ?? 0);
  }

  async getOverview(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);

    const [totalLeads, totalPortfolio, totalDealsWon, totalRef, portfolioFromRef, totalRevenue] = await Promise.all([
      this.prisma.lead.count({ where: { createdAt: { gte: range.from, lte: range.to } } }),
      this.prisma.listing.count({ where: { createdAt: { gte: range.from, lte: range.to } } }),
      this.prisma.deal.count({ where: { status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to } } }),
      this.prisma.lead.count({ where: this.referralWhere(range) }),
      this.prisma.deal.count({
        where: {
          lead: this.referralWhere(range),
          OR: [{ listingId: { not: null } }, { status: { in: [DealStatus.READY_FOR_MATCHING, DealStatus.ASSIGNED, DealStatus.WON] } }],
        },
      }),
      this.getRevenueSum(range),
    ]);

    const conversionRefToPortfolio = totalRef > 0 ? Number(((portfolioFromRef / totalRef) * 100).toFixed(2)) : 0;
    const conversionPortfolioToSale = totalPortfolio > 0 ? Number(((totalDealsWon / totalPortfolio) * 100).toFixed(2)) : 0;

    return {
      from: range.from,
      to: range.to,
      totalRevenue,
      totalDealsWon,
      totalLeads,
      totalPortfolio,
      conversionRefToPortfolio,
      conversionPortfolioToSale,
    };
  }

  async getFunnelRefToPortfolio(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const totalRef = await this.prisma.lead.count({ where: this.referralWhere(range) });

    const portfolioFromRef = await this.prisma.deal.count({
      where: {
        lead: this.referralWhere(range),
        OR: [{ listingId: { not: null } }, { status: { in: [DealStatus.READY_FOR_MATCHING, DealStatus.ASSIGNED, DealStatus.WON] } }],
      },
    });

    const partners = await this.prisma.user.findMany({
      where: { role: Role.HUNTER },
      select: { id: true, name: true, email: true },
      orderBy: { createdAt: 'asc' },
    });

    const breakdownByPartner = await Promise.all(
      partners.map(async (partner) => {
        const refCount = await this.prisma.lead.count({
          where: { createdAt: { gte: range.from, lte: range.to }, sourceUserId: partner.id },
        });
        const portfolioCount = await this.prisma.deal.count({
          where: {
            lead: { createdAt: { gte: range.from, lte: range.to }, sourceUserId: partner.id },
            OR: [{ listingId: { not: null } }, { status: { in: [DealStatus.READY_FOR_MATCHING, DealStatus.ASSIGNED, DealStatus.WON] } }],
          },
        });
        const rate = refCount > 0 ? Number(((portfolioCount / refCount) * 100).toFixed(2)) : 0;
        return {
          partnerId: partner.id,
          name: partner.name || partner.email,
          refCount,
          portfolioCount,
          rate,
        };
      }),
    );

    breakdownByPartner.sort((a, b) => b.refCount - a.refCount);

    return {
      from: range.from,
      to: range.to,
      totalRef,
      portfolioFromRef,
      refToPortfolioRate: totalRef > 0 ? Number(((portfolioFromRef / totalRef) * 100).toFixed(2)) : 0,
      breakdownByPartner,
      breakdownByChannel: [], // TODO: lead channel alanı netleşince doldurulacak.
    };
  }

  async getFunnelPortfolioToSale(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);

    const [totalPortfolio, salesFromPortfolio, wonDeals] = await Promise.all([
      this.prisma.listing.count({ where: { createdAt: { gte: range.from, lte: range.to } } }),
      this.prisma.deal.count({
        where: { status: DealStatus.WON, listingId: { not: null }, updatedAt: { gte: range.from, lte: range.to } },
      }),
      this.prisma.deal.findMany({
        where: { status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to }, consultantId: { not: null } },
        select: { consultantId: true, createdAt: true, updatedAt: true },
      }),
    ]);

    const timeDiffDays = wonDeals
      .map((d) => Math.max(0, (new Date(d.updatedAt).getTime() - new Date(d.createdAt).getTime()) / (1000 * 60 * 60 * 24)))
      .filter((v) => Number.isFinite(v));

    const avgTimeToCloseDays =
      timeDiffDays.length > 0 ? Number((timeDiffDays.reduce((sum, d) => sum + d, 0) / timeDiffDays.length).toFixed(2)) : 0;

    const consultants = await this.prisma.user.findMany({
      where: { role: Role.CONSULTANT },
      select: { id: true, name: true, email: true },
    });

    const breakdownByConsultant = await Promise.all(
      consultants.map(async (consultant) => {
        const portfolioCount = await this.prisma.listing.count({
          where: { consultantId: consultant.id, createdAt: { gte: range.from, lte: range.to } },
        });
        const salesCount = await this.prisma.deal.count({
          where: {
            consultantId: consultant.id,
            status: DealStatus.WON,
            updatedAt: { gte: range.from, lte: range.to },
          },
        });
        return {
          consultantId: consultant.id,
          name: consultant.name || consultant.email,
          portfolioCount,
          salesCount,
          rate: portfolioCount > 0 ? Number(((salesCount / portfolioCount) * 100).toFixed(2)) : 0,
        };
      }),
    );

    breakdownByConsultant.sort((a, b) => b.salesCount - a.salesCount);

    return {
      from: range.from,
      to: range.to,
      totalPortfolio,
      salesFromPortfolio,
      portfolioToSaleRate: totalPortfolio > 0 ? Number(((salesFromPortfolio / totalPortfolio) * 100).toFixed(2)) : 0,
      avgTimeToCloseDays,
      breakdownByConsultant,
    };
  }

  async getLeaderboardConsultants(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const consultants = await this.prisma.user.findMany({
      where: { role: Role.CONSULTANT },
      select: { id: true, name: true, email: true },
    });

    const rows = await Promise.all(
      consultants.map(async (consultant) => {
        const [portfolioCount, dealsWonCount, revenueAgg] = await Promise.all([
          this.prisma.listing.count({ where: { consultantId: consultant.id, createdAt: { gte: range.from, lte: range.to } } }),
          this.prisma.deal.count({
            where: { consultantId: consultant.id, status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to } },
          }),
          this.prisma.offer.aggregate({
            _sum: { amount: true },
            where: {
              consultantId: consultant.id,
              status: OfferStatus.ACCEPTED,
              OR: [{ decidedAt: { gte: range.from, lte: range.to } }, { updatedAt: { gte: range.from, lte: range.to } }],
            },
          }),
        ]);

        const revenueSum = Number(revenueAgg._sum.amount ?? 0);
        const avgCommission = Number((revenueSum * 0.03).toFixed(2)); // TODO: gerçek komisyon tablosu bağlanacak.

        const wonDeals = await this.prisma.deal.findMany({
          where: { consultantId: consultant.id, status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to } },
          select: { createdAt: true, updatedAt: true },
        });

        const avgCloseDays =
          wonDeals.length > 0
            ? Number(
                (
                  wonDeals.reduce(
                    (sum, d) => sum + Math.max(0, (new Date(d.updatedAt).getTime() - new Date(d.createdAt).getTime()) / (1000 * 60 * 60 * 24)),
                    0,
                  ) / wonDeals.length
                ).toFixed(2),
              )
            : 0;

        return {
          consultantId: consultant.id,
          name: consultant.name || consultant.email,
          dealsWonCount,
          revenueSum,
          avgCommission,
          conversionRate: portfolioCount > 0 ? Number(((dealsWonCount / portfolioCount) * 100).toFixed(2)) : 0,
          avgCloseDays,
        };
      }),
    );

    rows.sort((a, b) => (b.revenueSum === a.revenueSum ? b.dealsWonCount - a.dealsWonCount : b.revenueSum - a.revenueSum));

    return { from: range.from, to: range.to, rows };
  }

  async getLeaderboardPartners(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const partners = await this.prisma.user.findMany({
      where: { role: Role.HUNTER },
      select: { id: true, name: true, email: true },
    });

    const rows = await Promise.all(
      partners.map(async (partner) => {
        const [refCount, portfolioCount, salesAttributedCount, revenueAgg] = await Promise.all([
          this.prisma.lead.count({ where: { sourceUserId: partner.id, createdAt: { gte: range.from, lte: range.to } } }),
          this.prisma.deal.count({
            where: {
              lead: { sourceUserId: partner.id, createdAt: { gte: range.from, lte: range.to } },
              OR: [{ listingId: { not: null } }, { status: { in: [DealStatus.READY_FOR_MATCHING, DealStatus.ASSIGNED, DealStatus.WON] } }],
            },
          }),
          this.prisma.deal.count({
            where: {
              status: DealStatus.WON,
              updatedAt: { gte: range.from, lte: range.to },
              lead: { sourceUserId: partner.id },
            },
          }),
          this.prisma.offer.aggregate({
            _sum: { amount: true },
            where: {
              status: OfferStatus.ACCEPTED,
              OR: [{ decidedAt: { gte: range.from, lte: range.to } }, { updatedAt: { gte: range.from, lte: range.to } }],
              lead: { sourceUserId: partner.id },
            },
          }),
        ]);

        const revenueAttributedSum = Number(revenueAgg._sum.amount ?? 0);
        return {
          partnerId: partner.id,
          name: partner.name || partner.email,
          refCount,
          portfolioCount,
          refToPortfolioRate: refCount > 0 ? Number(((portfolioCount / refCount) * 100).toFixed(2)) : 0,
          salesAttributedCount,
          revenueAttributedSum,
        };
      }),
    );

    rows.sort((a, b) => (b.refCount === a.refCount ? b.revenueAttributedSum - a.revenueAttributedSum : b.refCount - a.refCount));
    return { from: range.from, to: range.to, rows };
  }

  async getFinanceRevenue(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const rows = await this.prisma.offer.findMany({
      where: {
        status: OfferStatus.ACCEPTED,
        OR: [{ decidedAt: { gte: range.from, lte: range.to } }, { updatedAt: { gte: range.from, lte: range.to } }],
      },
      select: { amount: true, consultantId: true, updatedAt: true, decidedAt: true },
      orderBy: { updatedAt: 'asc' },
    });

    const revenueSum = rows.reduce((sum, row) => sum + Number(row.amount || 0), 0);

    const revenueByDayMap = new Map<string, number>();
    rows.forEach((row) => {
      const date = (row.decidedAt || row.updatedAt).toISOString().slice(0, 10);
      revenueByDayMap.set(date, Number((revenueByDayMap.get(date) || 0) + Number(row.amount || 0)));
    });

    const consultants = await this.prisma.user.findMany({
      where: { role: Role.CONSULTANT },
      select: { id: true, name: true, email: true },
    });
    const consultantNameMap = new Map(consultants.map((c) => [c.id, c.name || c.email]));

    const byConsultantMap = new Map<string, number>();
    rows.forEach((row) => {
      if (!row.consultantId) return;
      byConsultantMap.set(row.consultantId, Number((byConsultantMap.get(row.consultantId) || 0) + Number(row.amount || 0)));
    });

    const revenueByConsultant = Array.from(byConsultantMap.entries())
      .map(([consultantId, amount]) => ({ consultantId, name: consultantNameMap.get(consultantId) || consultantId, amount }))
      .sort((a, b) => b.amount - a.amount)
      .slice(0, 10);

    return {
      from: range.from,
      to: range.to,
      revenueSum,
      revenueByDay: Array.from(revenueByDayMap.entries())
        .map(([date, amount]) => ({ date, amount }))
        .sort((a, b) => a.date.localeCompare(b.date)),
      revenueByConsultant,
      revenueByRegion: [], // TODO: Bölge modeli netleşince doldurulacak.
    };
  }

  async getFinanceCommission(from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const revenue = await this.getFinanceRevenue(from, to);
    const commissionSum = Number((revenue.revenueSum * 0.03).toFixed(2)); // TODO: gerçek komisyon modeli bağlanacak.

    const commissionByRole = [
      { role: 'CONSULTANT', amount: Number((commissionSum * 0.5).toFixed(2)) },
      { role: 'HUNTER', amount: Number((commissionSum * 0.3).toFixed(2)) },
      { role: 'BROKER', amount: Number((commissionSum * 0.2).toFixed(2)) },
    ];

    const commissionByUser = revenue.revenueByConsultant.map((r) => ({
      userId: r.consultantId,
      name: r.name,
      amount: Number((r.amount * 0.03).toFixed(2)),
    }));

    return {
      from: range.from,
      to: range.to,
      commissionSum,
      commissionByRole,
      commissionByUser,
      pendingCommission: 0, // TODO: pending komisyon alanı netleşince doldurulacak.
    };
  }

  async getConsultantDetail(id: string, from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const consultant = await this.prisma.user.findUnique({ where: { id }, select: { id: true, name: true, email: true, role: true } });
    if (!consultant) return { id, name: 'Bilinmiyor', role: 'CONSULTANT', kpis: this.emptyDetailKpis(), recentActivities: [] };

    const [portfolioCount, dealsWonCount, revenueAgg, recentDeals] = await Promise.all([
      this.prisma.listing.count({ where: { consultantId: id, createdAt: { gte: range.from, lte: range.to } } }),
      this.prisma.deal.count({ where: { consultantId: id, status: DealStatus.WON, updatedAt: { gte: range.from, lte: range.to } } }),
      this.prisma.offer.aggregate({
        _sum: { amount: true },
        where: {
          consultantId: id,
          status: OfferStatus.ACCEPTED,
          OR: [{ decidedAt: { gte: range.from, lte: range.to } }, { updatedAt: { gte: range.from, lte: range.to } }],
        },
      }),
      this.prisma.deal.findMany({
        where: { consultantId: id },
        orderBy: { updatedAt: 'desc' },
        take: 8,
        select: { id: true, status: true, updatedAt: true, city: true, district: true },
      }),
    ]);

    return {
      id: consultant.id,
      name: consultant.name || consultant.email,
      role: consultant.role,
      kpis: {
        portfolioCount,
        dealsWonCount,
        revenueSum: Number(revenueAgg._sum.amount ?? 0),
      },
      recentActivities: recentDeals.map((d) => ({
        id: d.id,
        status: d.status,
        updatedAt: d.updatedAt,
        location: [d.city, d.district].filter(Boolean).join(' / ') || '-',
      })),
    };
  }

  async getPartnerDetail(id: string, from?: string, to?: string) {
    const range = this.resolveDateRange(from, to);
    const partner = await this.prisma.user.findUnique({ where: { id }, select: { id: true, name: true, email: true, role: true } });
    if (!partner) return { id, name: 'Bilinmiyor', role: 'HUNTER', kpis: this.emptyDetailKpis(), recentActivities: [] };

    const [refCount, portfolioCount, salesCount, revenueAgg, recentLeads] = await Promise.all([
      this.prisma.lead.count({ where: { sourceUserId: id, createdAt: { gte: range.from, lte: range.to } } }),
      this.prisma.deal.count({
        where: {
          lead: { sourceUserId: id, createdAt: { gte: range.from, lte: range.to } },
          OR: [{ listingId: { not: null } }, { status: { in: [DealStatus.READY_FOR_MATCHING, DealStatus.ASSIGNED, DealStatus.WON] } }],
        },
      }),
      this.prisma.deal.count({ where: { status: DealStatus.WON, lead: { sourceUserId: id }, updatedAt: { gte: range.from, lte: range.to } } }),
      this.prisma.offer.aggregate({
        _sum: { amount: true },
        where: {
          status: OfferStatus.ACCEPTED,
          lead: { sourceUserId: id },
          OR: [{ decidedAt: { gte: range.from, lte: range.to } }, { updatedAt: { gte: range.from, lte: range.to } }],
        },
      }),
      this.prisma.lead.findMany({
        where: { sourceUserId: id },
        orderBy: { updatedAt: 'desc' },
        take: 8,
        select: { id: true, status: true, updatedAt: true },
      }),
    ]);

    return {
      id: partner.id,
      name: partner.name || partner.email,
      role: partner.role,
      kpis: {
        refCount,
        portfolioCount,
        salesCount,
        revenueAttributedSum: Number(revenueAgg._sum.amount ?? 0),
      },
      recentActivities: recentLeads.map((lead) => ({
        id: lead.id,
        status: lead.status,
        updatedAt: lead.updatedAt,
      })),
    };
  }

  private emptyDetailKpis() {
    return {
      portfolioCount: 0,
      dealsWonCount: 0,
      revenueSum: 0,
      refCount: 0,
      salesCount: 0,
      revenueAttributedSum: 0,
    };
  }
}
