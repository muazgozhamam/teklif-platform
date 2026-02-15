import { AuditEntityType, Role } from '@prisma/client';
import { canonicalizeAction, canonicalizeEntity } from '../audit/audit-normalization';
import { AllocationsService } from './allocations.service';

describe('AllocationsService', () => {
  function buildService(overrides?: {
    snapshotFindUnique?: (args: any) => any;
    allocationFindMany?: (args: any) => any;
    allocationCreate?: (args: any) => any;
    allocationFindUnique?: (args: any) => any;
    allocationUpdate?: (args: any) => any;
    allocationCount?: (args: any) => any;
    allocationList?: (args: any) => any;
    allocationUpdateMany?: (args: any) => any;
    snapshotIncludeAllocations?: (args: any) => any;
  }) {
    const prisma = {
      commissionSnapshot: {
        findUnique: jest.fn(
          overrides?.snapshotFindUnique ??
            overrides?.snapshotIncludeAllocations ??
            (async () => ({
              id: 'snap-1',
              totalCommission: 30000,
              hunterAmount: 3000,
              brokerAmount: 3000,
              consultantAmount: 21000,
              platformAmount: 3000,
              deal: { id: 'deal-1', consultantId: 'consultant-1' },
              allocations: [],
            })),
        ),
      },
      commissionAllocation: {
        findMany: jest.fn(overrides?.allocationFindMany ?? (async () => [])),
        create: jest.fn(overrides?.allocationCreate ?? (async ({ data }: any) => ({ id: 'alloc-1', ...data }))),
        findUnique: jest.fn(overrides?.allocationFindUnique ?? (async ({ where }: any) => ({ id: where.id, state: 'PENDING', snapshotId: 'snap-1', exportedAt: null }))),
        update: jest.fn(overrides?.allocationUpdate ?? (async ({ where, data }: any) => ({ id: where.id, state: data.state, snapshotId: 'snap-1' }))),
        updateMany: jest.fn(overrides?.allocationUpdateMany ?? (async () => ({ count: 1 }))),
        count: jest.fn(overrides?.allocationCount ?? (async () => 1)),
      },
    };
    const audit = { log: jest.fn(async () => ({ ok: true })) };
    const service = new AllocationsService(prisma as any, audit as any);
    return { service, prisma, audit };
  }

  it('creates allocations when none exist and emits audit', async () => {
    const { service, audit } = buildService();
    const rows = await service.generateAllocationsForSnapshot('snap-1');
    expect(rows).toHaveLength(1);
    expect(rows[0].beneficiaryUserId).toBe('consultant-1');
    expect(rows[0].role).toBe(Role.CONSULTANT);
    expect(rows[0].percent).toBe(100);
    expect(rows[0].amount).toBe(21000);
    const call = (audit.log as jest.Mock).mock.calls.find((c) => c[0].action === 'COMMISSION_ALLOCATED')?.[0];
    expect(call).toBeDefined();
    expect(canonicalizeAction(call.action)).toBe('COMMISSION_ALLOCATED');
    expect(canonicalizeEntity(call.entityType)).toBe('COMMISSION_CONFIG');
    expect(call.entityType).toBe(AuditEntityType.COMMISSION);
  });

  it('is idempotent and returns existing rows on second call', async () => {
    const existing = [{ id: 'alloc-existing', snapshotId: 'snap-1' }];
    let first = true;
    const { service, audit } = buildService({
      allocationFindMany: async () => {
        if (first) {
          first = false;
          return [];
        }
        return existing;
      },
    });
    const _firstRows = await service.generateAllocationsForSnapshot('snap-1');
    const secondRows = await service.generateAllocationsForSnapshot('snap-1');
    expect(secondRows).toEqual(existing);
    expect((audit.log as jest.Mock).mock.calls.filter((c) => c[0].action === 'COMMISSION_ALLOCATED')).toHaveLength(1);
  });

  it('approve/void state transitions emit audits', async () => {
    const { service, audit } = buildService();
    const approved = await service.approve('alloc-1');
    expect(approved?.state).toBe('APPROVED');
    const voided = await service.void('alloc-2');
    expect(voided?.state).toBe('VOID');
    expect((audit.log as jest.Mock).mock.calls.some((c) => c[0].action === 'COMMISSION_ALLOCATION_APPROVED')).toBe(true);
    expect((audit.log as jest.Mock).mock.calls.some((c) => c[0].action === 'COMMISSION_ALLOCATION_VOIDED')).toBe(true);
  });

  it('exports csv with header and row fields', async () => {
    const { service } = buildService({
      allocationFindMany: async () => [
        {
          id: 'alloc-1',
          snapshotId: 'snap-1',
          beneficiaryUserId: 'u-1',
          role: 'CONSULTANT',
          percent: 100,
          amount: 21000,
          state: 'APPROVED',
          createdAt: new Date('2026-02-15T10:00:00.000Z'),
          exportedAt: null,
          exportBatchId: null,
          snapshot: { id: 'snap-1', dealId: 'deal-1' },
          beneficiary: { id: 'u-1', email: 'c@test.com', role: 'CONSULTANT' },
        },
      ],
    });
    const out = await service.exportCsv({ state: 'APPROVED' });
    expect(out.count).toBe(1);
    expect(out.csv).toContain('id,snapshotId,dealId,beneficiaryUserId');
    expect(out.csv).toContain('alloc-1,snap-1,deal-1,u-1,c@test.com');
  });

  it('markExported is idempotent and emits export audit only for newly marked rows', async () => {
    const { service, audit } = buildService({
      allocationFindMany: async () => [
        { id: 'a1', snapshotId: 'snap-1', exportedAt: null, state: 'APPROVED' },
        { id: 'a2', snapshotId: 'snap-1', exportedAt: new Date('2026-02-15T10:00:00.000Z'), state: 'APPROVED' },
      ],
    });
    const result = await service.markExported(['a1', 'a2', 'missing'], { actorUserId: 'admin-1', actorRole: 'ADMIN' }, 'batch-1');
    expect(result).toEqual({
      requested: 3,
      found: 2,
      newlyMarked: 1,
      alreadyExported: 1,
      invalidState: 0,
      missing: 1,
    });
    expect((audit.log as jest.Mock).mock.calls.filter((c) => c[0].action === 'COMMISSION_ALLOCATION_EXPORTED')).toHaveLength(1);
  });

  it('markExported rejects non-APPROVED allocations', async () => {
    const { service } = buildService({
      allocationFindMany: async () => [{ id: 'a1', snapshotId: 'snap-1', exportedAt: null, state: 'PENDING' }],
    });
    await expect(service.markExported(['a1'])).rejects.toThrow('Only APPROVED allocations can be exported');
  });

  it('approve/void reject exported allocations (immutability)', async () => {
    const { service } = buildService({
      allocationFindUnique: async () => ({
        id: 'a1',
        state: 'PENDING',
        snapshotId: 'snap-1',
        exportedAt: new Date('2026-02-15T10:00:00.000Z'),
      }),
    });
    await expect(service.approve('a1')).rejects.toThrow('immutable');
    await expect(service.void('a1')).rejects.toThrow('immutable');
  });

  it('validateSnapshotIntegrity returns ok=true when invariants hold', async () => {
    const { service } = buildService({
      snapshotIncludeAllocations: async () => ({
        id: 'snap-1',
        totalCommission: 30000,
        hunterAmount: 3000,
        brokerAmount: 3000,
        consultantAmount: 21000,
        platformAmount: 3000,
        allocations: [
          {
            id: 'a1',
            amount: 21000,
            state: 'APPROVED',
            exportedAt: new Date('2026-02-15T10:00:00.000Z'),
            exportBatchId: 'batch-1',
          },
        ],
      }),
    });
    const out = await service.validateSnapshotIntegrity('snap-1');
    expect(out.ok).toBe(true);
    expect(out.checks.mathOk).toBe(true);
    expect(out.checks.allocationVsConsultantOk).toBe(true);
    expect(out.checks.exportBatchIntegrityOk).toBe(true);
  });
});
