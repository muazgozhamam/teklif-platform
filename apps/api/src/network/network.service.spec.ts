import { BadRequestException } from '@nestjs/common';
import { AuditEntityType, Role } from '@prisma/client';
import { NetworkService } from './network.service';

describe('NetworkService', () => {
  const actor = { actorUserId: 'admin-1', actorRole: 'ADMIN' };

  function buildService(overrides?: {
    userFindUnique?: (args: any) => any;
    userUpdate?: (args: any) => any;
    splitFindUnique?: (args: any) => any;
    splitUpsert?: (args: any) => any;
    splitFindMany?: (args: any) => any;
  }) {
    const prisma = {
      user: {
        findUnique: jest.fn(overrides?.userFindUnique ?? (async () => null)),
        update: jest.fn(overrides?.userUpdate ?? (async ({ where, data }: any) => ({ id: where.id, parentId: data.parentId }))),
      },
      commissionSplitConfig: {
        findUnique: jest.fn(overrides?.splitFindUnique ?? (async () => null)),
        upsert: jest.fn(overrides?.splitUpsert ?? (async ({ create, update }: any) => ({ id: 'cfg-1', role: create?.role ?? update?.role, percent: create?.percent ?? update?.percent }))),
        findMany: jest.fn(overrides?.splitFindMany ?? (async () => [])),
      },
    };

    const audit = { log: jest.fn(async () => ({ id: 'audit-1' })) };
    const service = new NetworkService(prisma as any, audit as any);
    return { service, prisma, audit };
  }

  it('sets parent successfully', async () => {
    const users: Record<string, any> = {
      child: { id: 'child', parentId: null },
      parent: { id: 'parent', parentId: null },
    };
    const { service, audit } = buildService({
      userFindUnique: async ({ where }: any) => users[where.id] ?? null,
      userUpdate: async ({ where, data }: any) => ({ id: where.id, parentId: data.parentId }),
    });

    const result = await service.setParent('child', 'parent', actor);
    expect(result).toEqual({ id: 'child', parentId: 'parent' });
    expect(audit.log).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'NETWORK_PARENT_SET',
        entityType: AuditEntityType.USER,
        entityId: 'child',
      }),
    );
  });

  it('prevents cycle while setting parent', async () => {
    const users: Record<string, any> = {
      child: { id: 'child', parentId: null },
      parent: { id: 'parent', parentId: 'child' },
    };
    const { service } = buildService({
      userFindUnique: async ({ where }: any) => users[where.id] ?? null,
    });

    await expect(service.setParent('child', 'parent', actor)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('validates commission split percent range', async () => {
    const { service } = buildService();
    await expect(service.setCommissionSplit(Role.BROKER, 101, actor)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.setCommissionSplit(Role.BROKER, -1, actor)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('writes audit entry for commission split config', async () => {
    const { service, audit } = buildService({
      splitUpsert: async () => ({ id: 'cfg-1', role: Role.HUNTER, percent: 12.5 }),
    });

    const result = await service.setCommissionSplit(Role.HUNTER, 12.5, actor);
    expect(result).toEqual(expect.objectContaining({ id: 'cfg-1', role: Role.HUNTER, percent: 12.5 }));
    expect(audit.log).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'COMMISSION_SPLIT_CONFIG_SET',
        entityType: AuditEntityType.COMMISSION_CONFIG,
      }),
    );
  });

  it('getDirectParent returns parent after setParent', async () => {
    const users: Record<string, any> = {
      child: { id: 'child', role: Role.HUNTER, parentId: null },
      parent: { id: 'parent', role: Role.BROKER, parentId: null },
    };
    const { service } = buildService({
      userFindUnique: async ({ where, select }: any) => {
        const u = users[where.id];
        if (!u) return null;
        if (select?.parent) {
          return {
            parent: u.parentId ? { id: u.parentId, role: users[u.parentId].role } : null,
          };
        }
        return { id: u.id, parentId: u.parentId, role: u.role };
      },
      userUpdate: async ({ where, data }: any) => {
        users[where.id].parentId = data.parentId;
        return { id: where.id, parentId: data.parentId };
      },
    });

    await service.setParent('child', 'parent', actor);
    const directParent = await service.getDirectParent('child');
    expect(directParent).toEqual({ id: 'parent', role: Role.BROKER });
  });

  it('getUpline returns ordered chain and respects maxDepth', async () => {
    const users: Record<string, any> = {
      child: { id: 'child', role: Role.HUNTER, parentId: 'mid' },
      mid: { id: 'mid', role: Role.CONSULTANT, parentId: 'root' },
      root: { id: 'root', role: Role.BROKER, parentId: null },
    };
    const { service } = buildService({
      userFindUnique: async ({ where }: any) => users[where.id] ?? null,
    });

    const full = await service.getUpline('child');
    expect(full).toEqual([
      { id: 'mid', role: Role.CONSULTANT, parentId: 'root' },
      { id: 'root', role: Role.BROKER, parentId: null },
    ]);

    const limited = await service.getUpline('child', 1);
    expect(limited).toEqual([{ id: 'mid', role: Role.CONSULTANT, parentId: 'root' }]);
  });

  it('getEffectiveCommissionSplit uses fallback when no config exists', async () => {
    const { service } = buildService({
      splitFindUnique: async () => null,
    });
    await expect(service.getEffectiveCommissionSplit(Role.BROKER, 30)).resolves.toBe(30);
    await expect(service.getEffectiveCommissionSplit(Role.BROKER, 130)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('getSplitMap returns role map with configured values', async () => {
    const { service } = buildService({
      splitFindMany: async () => [
        { role: Role.BROKER, percent: 17.5 },
        { role: Role.HUNTER, percent: 9.25 },
      ],
    });

    const map = await service.getSplitMap();
    expect(map.BROKER).toBe(17.5);
    expect(map.HUNTER).toBe(9.25);
    expect(map.ADMIN).toBeNull();
    expect(map.USER).toBeNull();
    expect(map.CONSULTANT).toBeNull();
  });
});
