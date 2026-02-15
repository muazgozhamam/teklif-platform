import { MatchingService } from './matching.service';

describe('MatchingService', () => {
  it('loadByConsultant uses single groupBy and fills missing consultants with zero', async () => {
    const prisma: any = {
      deal: {
        groupBy: jest.fn().mockResolvedValue([
          { consultantId: 'c1', _count: { _all: 3 } },
        ]),
      },
    };

    const service = new MatchingService(prisma);
    const result: Map<string, number> = await (service as any).loadByConsultant(['c1', 'c2']);

    expect(prisma.deal.groupBy).toHaveBeenCalledTimes(1);
    expect(result.get('c1')).toBe(3);
    expect(result.get('c2')).toBe(0);
  });

  it('pickConsultantForDeal uses load map as tie-breaker when scores are equal', async () => {
    const prisma: any = {
      deal: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'd1',
          city: null,
          district: null,
          type: null,
          rooms: null,
        }),
        groupBy: jest.fn().mockResolvedValue([
          { consultantId: 'c1', _count: { _all: 5 } },
          { consultantId: 'c2', _count: { _all: 1 } },
        ]),
      },
      consultant: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'c1', city: null, district: null, types: [], rooms: [] },
          { id: 'c2', city: null, district: null, types: [], rooms: [] },
        ]),
      },
    };

    const service = new MatchingService(prisma);
    const picked = await service.pickConsultantForDeal('d1');

    expect(prisma.deal.groupBy).toHaveBeenCalledTimes(1);
    expect(picked.consultantId).toBe('c2');
    expect((picked.reason as any).bestLoad).toBe(1);
  });
});
