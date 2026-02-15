import { BadRequestException } from '@nestjs/common';
import { AuditEntityType } from '@prisma/client';
import { canonicalizeAction, canonicalizeEntity } from '../audit/audit-normalization';
import { OrgService } from './org.service';

describe('OrgService', () => {
  const actor = { actorUserId: 'admin-1', actorRole: 'ADMIN' };

  function buildService(overrides?: {
    regionCreate?: (args: any) => any;
    regionFindMany?: (args: any) => any;
    regionFindUnique?: (args: any) => any;
    officeCreate?: (args: any) => any;
    officeFindMany?: (args: any) => any;
    officeFindUnique?: (args: any) => any;
    officeUpdate?: (args: any) => any;
    userFindUnique?: (args: any) => any;
    userUpdate?: (args: any) => any;
    userFindMany?: (args: any) => any;
    leadFindUnique?: (args: any) => any;
    leadUpdate?: (args: any) => any;
  }) {
    const prisma = {
      region: {
        create: jest.fn(overrides?.regionCreate ?? (async ({ data }: any) => ({ id: 'region-1', ...data }))),
        findMany: jest.fn(overrides?.regionFindMany ?? (async () => [])),
        findUnique: jest.fn(overrides?.regionFindUnique ?? (async () => ({ id: 'region-1' }))),
      },
      office: {
        create: jest.fn(overrides?.officeCreate ?? (async ({ data }: any) => ({ id: 'office-1', ...data }))),
        findMany: jest.fn(overrides?.officeFindMany ?? (async () => [])),
        findUnique: jest.fn(overrides?.officeFindUnique ?? (async () => ({ id: 'office-1' }))),
        update: jest.fn(
          overrides?.officeUpdate ??
            (async ({ where, data }: any) => ({ id: where.id, regionId: 'region-1', brokerId: data.brokerId ?? null, overridePercent: data.overridePercent ?? null })),
        ),
      },
      user: {
        findUnique: jest.fn(overrides?.userFindUnique ?? (async ({ where }: any) => ({ id: where.id, officeId: null }))),
        update: jest.fn(overrides?.userUpdate ?? (async ({ where, data }: any) => ({ id: where.id, officeId: data.officeId ?? null }))),
        findMany: jest.fn(overrides?.userFindMany ?? (async () => [])),
      },
      lead: {
        findUnique: jest.fn(overrides?.leadFindUnique ?? (async ({ where }: any) => ({ id: where.id, regionId: null }))),
        update: jest.fn(overrides?.leadUpdate ?? (async ({ where, data }: any) => ({ id: where.id, regionId: data.regionId ?? null }))),
      },
    };
    const audit = { log: jest.fn(async () => ({ ok: true })) };
    const service = new OrgService(prisma as any, audit as any);
    return { service, prisma, audit };
  }

  it('createRegion + listRegions', async () => {
    const { service, audit } = buildService({
      regionFindMany: async () => [{ id: 'r1', city: 'Istanbul', district: 'Kadikoy' }],
    });
    const created = await service.createRegion('Istanbul', 'Kadikoy', actor);
    expect(created.city).toBe('Istanbul');
    const list = await service.listRegions('Istan');
    expect(list).toHaveLength(1);

    const call = (audit.log as jest.Mock).mock.calls.find((c) => c[0].action === 'REGION_CREATED')?.[0];
    expect(call.entityType).toBe('REGION');
    expect(canonicalizeAction(call.action)).toBe('REGION_CREATED');
    expect(canonicalizeEntity(call.entityType)).toBe('REGION');
  });

  it('createOffice + listOffices', async () => {
    const { service, audit } = buildService({
      officeFindMany: async () => [{ id: 'o1', name: 'Office A' }],
      userFindUnique: async ({ where }: any) => ({ id: where.id }),
    });
    const created = await service.createOffice('Office A', 'region-1', 'broker-1', 12.5, actor);
    expect(created.name).toBe('Office A');
    const list = await service.listOffices('region-1');
    expect(list).toHaveLength(1);

    const call = (audit.log as jest.Mock).mock.calls.find((c) => c[0].action === 'OFFICE_CREATED')?.[0];
    expect(call.entityType).toBe('OFFICE');
    expect(canonicalizeAction(call.action)).toBe('OFFICE_CREATED');
    expect(canonicalizeEntity(call.entityType)).toBe('OFFICE');
  });

  it('assignUserOffice assign + unassign', async () => {
    let state: string | null = null;
    const { service } = buildService({
      userFindUnique: async ({ where }: any) => ({ id: where.id, officeId: state }),
      userUpdate: async ({ where, data }: any) => {
        state = data.officeId ?? null;
        return { id: where.id, officeId: state };
      },
    });

    const assigned = await service.assignUserOffice('user-1', 'office-1', actor);
    expect(assigned.officeId).toBe('office-1');
    const unassigned = await service.assignUserOffice('user-1', null, actor);
    expect(unassigned.officeId).toBeNull();
  });

  it('overridePercent validation', async () => {
    const { service } = buildService();
    await expect(service.createOffice('Office', 'region-1', null, 101, actor)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.createOffice('Office', 'region-1', null, -1, actor)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('assignLeadRegion updates and audits', async () => {
    const { service, audit } = buildService();
    const updated = await service.assignLeadRegion('lead-1', 'region-1', actor);
    expect(updated.regionId).toBe('region-1');
    const call = (audit.log as jest.Mock).mock.calls.find((c) => c[0].action === 'LEAD_REGION_ASSIGNED')?.[0];
    expect(call.entityType).toBe(AuditEntityType.LEAD);
    expect(canonicalizeAction(call.action)).toBe('LEAD_REGION_ASSIGNED');
    expect(canonicalizeEntity(call.entityType)).toBe('LEAD');
  });

  it('listOfficeUsers and listRegionOffices', async () => {
    const { service } = buildService({
      userFindUnique: async ({ where }: any) => {
        if (where.id === 'office-1') return null;
        return { id: where.id, officeId: null };
      },
      officeFindUnique: async ({ where }: any) => {
        if (where.id === 'office-1') return { id: 'office-1' };
        return null;
      },
      regionFindUnique: async ({ where }: any) => {
        if (where.id === 'region-1') return { id: 'region-1' };
        return null;
      },
      officeFindMany: async () => [{ id: 'office-1', name: 'Office 1', regionId: 'region-1', brokerId: null, overridePercent: null }],
    });

    const users = await service.listOfficeUsers('office-1');
    expect(Array.isArray(users)).toBe(true);
    const offices = await service.listRegionOffices('region-1');
    expect(offices).toHaveLength(1);
  });

  it('assignOfficeBroker + setOfficeOverridePolicy + franchiseSummary', async () => {
    const { service } = buildService({
      officeFindUnique: async ({ where }: any) => {
        if (where.id === 'office-1') return { id: 'office-1', brokerId: null };
        return null;
      },
      userFindUnique: async ({ where }: any) => {
        if (where.id === 'broker-1') return { id: 'broker-1', role: 'BROKER', officeId: null };
        return { id: where.id, role: 'CONSULTANT', officeId: null };
      },
      officeFindMany: async () => [
        { id: 'office-1', name: 'Office 1', regionId: 'region-1', brokerId: 'broker-1', overridePercent: 12.5 },
      ],
      regionFindMany: async () => [{ id: 'region-1', city: 'Istanbul', district: 'Kadikoy' }],
      officeUpdate: async ({ where, data }: any) => ({
        id: where.id,
        regionId: 'region-1',
        brokerId: data.brokerId ?? 'broker-1',
        overridePercent: data.overridePercent ?? 12.5,
      }),
    });

    const brokerAssigned = await service.assignOfficeBroker('office-1', 'broker-1');
    expect(brokerAssigned.brokerId).toBe('broker-1');

    const overrideSet = await service.setOfficeOverridePolicy('office-1', 12.5);
    expect(overrideSet.overridePercent).toBe(12.5);

    const summary = await service.getFranchiseSummary();
    expect(summary.totals.regions).toBe(1);
    expect(summary.totals.offices).toBe(1);
    expect(summary.totals.officesWithBroker).toBe(1);
    expect(summary.totals.officesWithOverridePolicy).toBe(1);
    expect(summary.regions[0].officeStats.total).toBe(1);
  });
});
