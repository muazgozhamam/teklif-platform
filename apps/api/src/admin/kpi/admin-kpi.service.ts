import { Injectable } from '@nestjs/common';
import { DealStatus, LeadStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

type FunnelQuery = {
  officeId?: string;
  regionId?: string;
};

@Injectable()
export class AdminKpiService {
  constructor(private readonly prisma: PrismaService) {}

  private pct(part: number, total: number): number {
    if (total <= 0) return 0;
    return Number(((part / total) * 100).toFixed(2));
  }

  async getFunnel(query: FunnelQuery) {
    const officeId = String(query.officeId ?? '').trim();
    const regionId = String(query.regionId ?? '').trim();

    const leadWhere: any = {};
    if (regionId) leadWhere.regionId = regionId;

    const dealWhere: any = {};
    if (regionId) dealWhere.lead = { regionId };
    if (officeId) {
      dealWhere.consultant = {
        is: { officeId },
      };
    }

    const listingWhere: any = {};
    if (officeId) listingWhere.consultant = { is: { officeId } };
    if (regionId) listingWhere.deals = { some: { lead: { regionId } } };

    const [leadsTotal, leadsApproved, dealsTotal, listingsTotal, dealsWon] = await Promise.all([
      this.prisma.lead.count({ where: leadWhere }),
      this.prisma.lead.count({ where: { ...leadWhere, status: LeadStatus.APPROVED } }),
      this.prisma.deal.count({ where: dealWhere }),
      this.prisma.listing.count({ where: listingWhere }),
      this.prisma.deal.count({ where: { ...dealWhere, status: DealStatus.WON } }),
    ]);

    const conversion = {
      leadToApprovedPct: this.pct(leadsApproved, leadsTotal),
      approvedToDealPct: this.pct(dealsTotal, leadsApproved),
      dealToListingPct: this.pct(listingsTotal, dealsTotal),
      listingToWonPct: this.pct(dealsWon, listingsTotal),
      leadToWonPct: this.pct(dealsWon, leadsTotal),
    };

    return {
      filters: {
        officeId: officeId || null,
        regionId: regionId || null,
      },
      counts: {
        leadsTotal,
        leadsApproved,
        dealsTotal,
        listingsTotal,
        dealsWon,
      },
      conversion,
    };
  }
}
