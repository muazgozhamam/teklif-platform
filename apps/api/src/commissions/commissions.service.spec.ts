import { CommissionsService } from './commissions.service';

describe('CommissionsService admin filters', () => {
  function buildService() {
    const prisma = {
      commissionSnapshot: {
        findMany: jest.fn(async () => []),
        count: jest.fn(async () => 0),
      },
    };
    const service = new CommissionsService(prisma as any);
    return { service, prisma };
  }

  it('default behavior unchanged when officeId/regionId absent', async () => {
    const { service, prisma } = buildService();
    await service.listAdmin({});
    const where = (prisma.commissionSnapshot.findMany as jest.Mock).mock.calls[0][0].where;
    expect(where.AND).toBeUndefined();
  });

  it('applies officeId and regionId filters', async () => {
    const { service, prisma } = buildService();
    await service.listAdmin({ officeId: 'office-1', regionId: 'region-1' });
    const where = (prisma.commissionSnapshot.findMany as jest.Mock).mock.calls[0][0].where;
    expect(where).toEqual(
      expect.objectContaining({
        AND: expect.arrayContaining([
          { deal: { is: { consultant: { is: { officeId: 'office-1' } } } } },
          { deal: { is: { lead: { is: { regionId: 'region-1' } } } } },
        ]),
      }),
    );
  });
});

