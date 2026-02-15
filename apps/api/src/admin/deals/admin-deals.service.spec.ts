import { AdminDealsService } from './admin-deals.service';

describe('AdminDealsService', () => {
  function buildService() {
    const prisma = {
      deal: {
        findMany: jest.fn(async () => []),
        count: jest.fn(async () => 0),
      },
    };
    const service = new AdminDealsService(prisma as any);
    return { service, prisma };
  }

  it('default behavior unchanged when filters absent', async () => {
    const { service, prisma } = buildService();
    await service.list({});
    expect(prisma.deal.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: undefined,
      }),
    );
  });

  it('applies officeId and regionId filters', async () => {
    const { service, prisma } = buildService();
    await service.list({ officeId: 'office-1', regionId: 'region-1' });
    const where = (prisma.deal.findMany as jest.Mock).mock.calls[0][0].where;
    expect(where).toEqual(
      expect.objectContaining({
        AND: expect.arrayContaining([
          { consultant: { is: { officeId: 'office-1' } } },
          { lead: { regionId: 'region-1' } },
        ]),
      }),
    );
  });
});

