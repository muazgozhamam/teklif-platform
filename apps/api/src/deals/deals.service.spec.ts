import { AuditEntityType, DealStatus, Prisma } from '@prisma/client';
import { canonicalizeAction, canonicalizeEntity } from '../audit/audit-normalization';
import { DealsService } from './deals.service';

describe('DealsService network snapshot hook', () => {
  const originalFlag = process.env.NETWORK_COMMISSIONS_ENABLED;
  const originalAllocationFlag = process.env.COMMISSION_ALLOCATION_ENABLED;

  afterEach(() => {
    process.env.NETWORK_COMMISSIONS_ENABLED = originalFlag;
    process.env.COMMISSION_ALLOCATION_ENABLED = originalAllocationFlag;
    jest.restoreAllMocks();
  });

  function buildService(opts?: {
    networkEnabled?: boolean;
    splitPercent?: number | null;
    existingNetworkMeta?: Record<string, unknown> | null;
    existingSnapshot?: boolean;
    dealStatus?: DealStatus;
    consultantOfficeId?: string | null;
    officeRegionId?: string | null;
    officeOverridePercent?: number | null;
    allocationEnabled?: boolean;
  }) {
    const dealState = {
      id: 'deal-1',
      status: opts?.dealStatus ?? DealStatus.ASSIGNED,
      consultantId: 'consultant-1',
      commissionSnapshot: (opts?.existingSnapshot
        ? {
            id: 'snap-existing',
            dealId: 'deal-1',
            closingPrice: new Prisma.Decimal('1000000'),
            currency: 'TRY',
            totalCommission: new Prisma.Decimal('30000'),
            hunterAmount: new Prisma.Decimal('3000'),
            brokerAmount: new Prisma.Decimal('3000'),
            consultantAmount: new Prisma.Decimal('21000'),
            platformAmount: new Prisma.Decimal('3000'),
            rateUsedJson: { source: 'GLOBAL_CONFIG' },
            networkMeta: opts?.existingNetworkMeta ?? null,
          }
        : null) as any,
    };
    let snapshotState: any = null;

    if (opts?.networkEnabled) process.env.NETWORK_COMMISSIONS_ENABLED = '1';
    else process.env.NETWORK_COMMISSIONS_ENABLED = '0';
    if (opts?.allocationEnabled) process.env.COMMISSION_ALLOCATION_ENABLED = '1';
    else process.env.COMMISSION_ALLOCATION_ENABLED = '0';

    const prisma: any = {
      commissionConfig: {
        upsert: jest.fn(async () => ({
          id: 'default',
          baseRate: 0.03,
          hunterSplit: 10,
          brokerSplit: 10,
          consultantSplit: 70,
          platformSplit: 10,
        })),
      },
      consultantCommissionProfile: {
        findUnique: jest.fn(async () => null),
      },
      user: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where?.id === 'consultant-1') {
            return {
              id: 'consultant-1',
              role: 'CONSULTANT',
              officeId: opts?.consultantOfficeId === undefined ? 'office-1' : opts.consultantOfficeId,
            };
          }
          return null;
        }),
      },
      office: {
        findUnique: jest.fn(async ({ where }: any) => {
          if (where?.id === 'office-1') {
            return {
              id: 'office-1',
              regionId: opts?.officeRegionId === undefined ? 'region-1' : opts.officeRegionId,
              overridePercent: opts?.officeOverridePercent === undefined ? 12.5 : opts.officeOverridePercent,
            };
          }
          return null;
        }),
      },
      deal: {
        findUnique: jest.fn(async ({ include, where }: any) => {
          if (include?.commissionSnapshot) {
            return { ...dealState };
          }
          if (include?.lead || include?.consultant) {
            return { id: where.id, lead: {}, consultant: null, status: dealState.status };
          }
          return { id: where.id, consultantId: dealState.consultantId };
        }),
        update: jest.fn(async ({ data }: any) => {
          if (data?.status) dealState.status = data.status;
          return { ...dealState };
        }),
      },
      commissionSnapshot: {
        upsert: jest.fn(async ({ create }: any) => {
          snapshotState = {
            id: 'snap-1',
            dealId: create.dealId,
            closingPrice: new Prisma.Decimal(create.closingPrice),
            currency: create.currency,
            totalCommission: new Prisma.Decimal(create.totalCommission),
            hunterAmount: new Prisma.Decimal(create.hunterAmount),
            brokerAmount: new Prisma.Decimal(create.brokerAmount),
            consultantAmount: new Prisma.Decimal(create.consultantAmount),
            platformAmount: new Prisma.Decimal(create.platformAmount),
            rateUsedJson: create.rateUsedJson,
            networkMeta: null,
          };
          dealState.commissionSnapshot = snapshotState;
          return snapshotState;
        }),
        update: jest.fn(async ({ data }: any) => {
          snapshotState = { ...snapshotState, networkMeta: data.networkMeta };
          dealState.commissionSnapshot = snapshotState;
          return snapshotState;
        }),
      },
      $transaction: jest.fn(async (fn: any) =>
        fn({
          deal: prisma.deal,
          commissionSnapshot: prisma.commissionSnapshot,
        })),
    };

    const audit = {
      log: jest.fn(async () => ({ ok: true })),
    };
    const network = {
      getNetworkPath: jest.fn(async () => [
        { id: 'consultant-1', role: 'CONSULTANT', parentId: 'broker-1', email: 'c@test.com' },
        { id: 'broker-1', role: 'BROKER', parentId: null, email: 'b@test.com' },
      ]),
      getUpline: jest.fn(async () => [{ id: 'broker-1', role: 'BROKER', parentId: null }]),
      getSplitMap: jest.fn(async () => ({ USER: null, ADMIN: null, BROKER: 15, CONSULTANT: 70, HUNTER: 15 })),
      getCommissionSplitByRole: jest.fn(async () => (opts?.splitPercent === undefined ? 70 : opts?.splitPercent)),
    };
    const allocations = {
      generateAllocationsForSnapshot: jest.fn(async () => []),
    };

    const service = new DealsService(prisma, {} as any, audit as any, network as any, allocations as any);
    return { service, prisma, audit, network, allocations };
  }

  it('flag OFF: does not write networkMeta and does not emit network capture audit', async () => {
    const { service, prisma, audit, network } = buildService({ networkEnabled: false });
    const result = await service.markWon('deal-1', { closingPrice: 1000000, currency: 'TRY' });

    expect(result.snapshot.networkMeta).toBeNull();
    expect(prisma.commissionSnapshot.update).not.toHaveBeenCalled();
    expect(network.getNetworkPath).not.toHaveBeenCalled();
    expect(network.getCommissionSplitByRole).not.toHaveBeenCalled();
    expect(audit.log).not.toHaveBeenCalledWith(expect.objectContaining({ action: 'COMMISSION_SNAPSHOT_NETWORK_CAPTURED' }));
  });

  it('flag ON: writes networkMeta splitTrace and does not change commission amounts', async () => {
    const { service, prisma, audit } = buildService({ networkEnabled: true, splitPercent: 70 });
    const result = await service.markWon('deal-1', { closingPrice: 1000000, currency: 'TRY' });

    expect(prisma.commissionSnapshot.update).toHaveBeenCalledTimes(1);
    expect(result.snapshot.networkMeta).toEqual(
      expect.objectContaining({
        userId: 'consultant-1',
        path: ['consultant-1', 'broker-1'],
        upline: [{ id: 'broker-1', role: 'BROKER', parentId: null }],
        splitTrace: expect.objectContaining({
          sourceUserId: 'consultant-1',
          sourceUserRole: 'CONSULTANT',
          effectiveSplitPercent: 70,
          defaultPercent: 0,
        }),
        officeTrace: expect.objectContaining({
          sourceUserId: 'consultant-1',
          officeId: 'office-1',
          regionId: 'region-1',
          overridePercent: 12.5,
        }),
      }),
    );
    expect(result.snapshot.networkMeta.splitTrace.resolvedAt).toBeTruthy();
    expect(result.snapshot.totalCommission.toString()).toBe('30000');
    expect(result.snapshot.hunterAmount.toString()).toBe('3000');
    expect(result.snapshot.brokerAmount.toString()).toBe('3000');
    expect(result.snapshot.consultantAmount.toString()).toBe('21000');
    expect(result.snapshot.platformAmount.toString()).toBe('3000');
    expect(result.snapshot.networkMeta.officeTrace.resolvedAt).toBeTruthy();

    const call = (audit.log as jest.Mock).mock.calls.find(
      (c) => c?.[0]?.action === 'COMMISSION_SNAPSHOT_NETWORK_CAPTURED',
    )?.[0];
    expect(call).toBeDefined();
    expect(canonicalizeAction(call.action)).toBe('COMMISSION_SNAPSHOT_NETWORK_CAPTURED');
    expect(canonicalizeEntity(call.entityType as string)).toBe('COMMISSION_CONFIG');
    expect(call.entityType).toBe(AuditEntityType.COMMISSION);
  });

  it('flag ON: splitTrace uses null when split config missing', async () => {
    const { service } = buildService({ networkEnabled: true, splitPercent: null, consultantOfficeId: null });
    const result = await service.markWon('deal-1', { closingPrice: 1000000, currency: 'TRY' });
    expect(result.snapshot.networkMeta.splitTrace.effectiveSplitPercent).toBeNull();
    expect(result.snapshot.networkMeta.officeTrace).toEqual(
      expect.objectContaining({
        sourceUserId: 'consultant-1',
        officeId: null,
        regionId: null,
        overridePercent: null,
      }),
    );
  });

  it('does not overwrite existing officeTrace/splitTrace on existing snapshot', async () => {
    const existingMeta = {
      userId: 'consultant-1',
      path: ['consultant-1', 'broker-1'],
      splitMap: { CONSULTANT: 70 },
      splitTrace: {
        sourceUserId: 'consultant-1',
        sourceUserRole: 'CONSULTANT',
        effectiveSplitPercent: 65,
        defaultPercent: 0,
        resolvedAt: '2026-01-01T00:00:00.000Z',
      },
      officeTrace: {
        sourceUserId: 'consultant-1',
        officeId: 'office-legacy',
        regionId: 'region-legacy',
        overridePercent: 9,
        resolvedAt: '2026-01-01T00:00:00.000Z',
      },
    };
    const { service, prisma, audit } = buildService({
      networkEnabled: true,
      existingSnapshot: true,
      existingNetworkMeta: existingMeta,
      dealStatus: DealStatus.WON,
    });

    const result = await service.markWon('deal-1', { closingPrice: 1000000, currency: 'TRY' });
    expect(prisma.commissionSnapshot.update).not.toHaveBeenCalled();
    expect(result.snapshot.networkMeta).toEqual(existingMeta);
    expect(audit.log).not.toHaveBeenCalledWith(expect.objectContaining({ action: 'COMMISSION_SNAPSHOT_NETWORK_CAPTURED' }));
  });

  it('allocation hook: flag OFF does not generate allocations', async () => {
    const { service, allocations } = buildService({ networkEnabled: true, allocationEnabled: false });
    await service.markWon('deal-1', { closingPrice: 1000000, currency: 'TRY' });
    expect(allocations.generateAllocationsForSnapshot).not.toHaveBeenCalled();
  });

  it('allocation hook: flag ON generates allocations on markWon path', async () => {
    const { service, allocations } = buildService({ networkEnabled: true, allocationEnabled: true });
    await service.markWon('deal-1', { closingPrice: 1000000, currency: 'TRY' });
    expect(allocations.generateAllocationsForSnapshot).toHaveBeenCalledTimes(1);
    expect((allocations.generateAllocationsForSnapshot as jest.Mock).mock.calls[0][0]).toBe('snap-1');
  });
});
