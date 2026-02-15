import { AuditService } from './audit.service';

describe('AuditService tamper evidence', () => {
  function buildService(overrides?: {
    latestHash?: string | null;
    findManyRows?: any[];
  }) {
    const prisma = {
      auditLog: {
        findFirst: jest.fn(async () => ({ hash: overrides?.latestHash ?? null })),
        create: jest.fn(async ({ data }: any) => ({ id: 'a1', ...data })),
        findMany: jest.fn(async () => overrides?.findManyRows ?? []),
        count: jest.fn(async () => 0),
      },
      lead: { findUnique: jest.fn(async () => null) },
      deal: { findUnique: jest.fn(async () => null) },
      listing: { findUnique: jest.fn(async () => null) },
    };
    const service = new AuditService(prisma as any);
    return { service, prisma };
  }

  it('writes hash and prevHash on log create', async () => {
    const { service, prisma } = buildService({ latestHash: 'prev-hash-1' });
    const row = await service.log({
      actorUserId: 'u1',
      actorRole: 'ADMIN',
      action: 'USER_PATCHED' as any,
      entityType: 'USER' as any,
      entityId: 'u1',
      metaJson: { foo: 'bar' },
    });

    expect(row).toBeTruthy();
    const createCall = (prisma.auditLog.create as jest.Mock).mock.calls[0][0].data;
    expect(createCall.prevHash).toBe('prev-hash-1');
    expect(typeof createCall.hash).toBe('string');
    expect(createCall.hash.length).toBe(64);
  });

  it('integrityReport detects chain/hash issues', async () => {
    const rows = [
      {
        id: 'a1',
        createdAt: new Date('2026-02-15T10:00:00.000Z'),
        actorUserId: 'u1',
        actorRole: 'ADMIN',
        action: 'USER_PATCHED',
        entityType: 'USER',
        entityId: 'u1',
        beforeJson: null,
        afterJson: null,
        metaJson: null,
        prevHash: null,
        hash: null,
      },
      {
        id: 'a2',
        createdAt: new Date('2026-02-15T10:01:00.000Z'),
        actorUserId: 'u1',
        actorRole: 'ADMIN',
        action: 'USER_PATCHED',
        entityType: 'USER',
        entityId: 'u1',
        beforeJson: null,
        afterJson: null,
        metaJson: null,
        prevHash: 'x',
        hash: 'y',
      },
    ];
    const { service } = buildService({ findManyRows: rows });
    const out = await service.integrityReport({ take: 100 });
    expect(out.ok).toBe(false);
    expect(out.missingHashRows).toBe(1);
    expect(out.mismatchedRows.length).toBeGreaterThanOrEqual(1);
  });
});
