import { AdminKpiService } from './admin-kpi.service';

describe('AdminKpiService', () => {
  it('computes funnel counts and conversion percentages', async () => {
    const prisma: any = {
      lead: {
        count: jest
          .fn()
          .mockResolvedValueOnce(100)
          .mockResolvedValueOnce(40),
      },
      deal: {
        count: jest
          .fn()
          .mockResolvedValueOnce(20)
          .mockResolvedValueOnce(8),
      },
      listing: {
        count: jest.fn().mockResolvedValueOnce(10),
      },
    };

    const service = new AdminKpiService(prisma);
    const out = await service.getFunnel({});

    expect(out.counts.leadsTotal).toBe(100);
    expect(out.counts.leadsApproved).toBe(40);
    expect(out.counts.dealsTotal).toBe(20);
    expect(out.counts.listingsTotal).toBe(10);
    expect(out.counts.dealsWon).toBe(8);

    expect(out.conversion.leadToApprovedPct).toBe(40);
    expect(out.conversion.approvedToDealPct).toBe(50);
    expect(out.conversion.dealToListingPct).toBe(50);
    expect(out.conversion.listingToWonPct).toBe(80);
    expect(out.conversion.leadToWonPct).toBe(8);
  });

  it('returns zero conversion when denominators are zero', async () => {
    const prisma: any = {
      lead: { count: jest.fn().mockResolvedValueOnce(0).mockResolvedValueOnce(0) },
      deal: { count: jest.fn().mockResolvedValueOnce(0).mockResolvedValueOnce(0) },
      listing: { count: jest.fn().mockResolvedValueOnce(0) },
    };

    const service = new AdminKpiService(prisma);
    const out = await service.getFunnel({ officeId: 'o1', regionId: 'r1' });

    expect(out.conversion.leadToApprovedPct).toBe(0);
    expect(out.conversion.approvedToDealPct).toBe(0);
    expect(out.conversion.dealToListingPct).toBe(0);
    expect(out.conversion.listingToWonPct).toBe(0);
    expect(out.conversion.leadToWonPct).toBe(0);
    expect(out.filters.officeId).toBe('o1');
    expect(out.filters.regionId).toBe('r1');
  });
});
