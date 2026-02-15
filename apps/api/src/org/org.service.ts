import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditEntityType } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

type Actor = {
  actorUserId?: string | null;
  actorRole?: string | null;
};

@Injectable()
export class OrgService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async createRegion(city: string, district?: string, actor?: Actor) {
    const cityValue = String(city ?? '').trim();
    const districtValue = district === undefined || district === null ? null : String(district).trim() || null;
    if (!cityValue) throw new BadRequestException('city is required');

    const region = await this.prisma.region.create({
      data: { city: cityValue, district: districtValue },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'ADMIN',
      action: 'REGION_CREATED',
      entityType: 'REGION' as AuditEntityType,
      entityId: region.id,
      afterJson: { city: region.city, district: region.district },
    });
    return region;
  }

  async listRegions(city?: string) {
    const q = String(city ?? '').trim();
    return this.prisma.region.findMany({
      where: q ? { city: { contains: q, mode: 'insensitive' } } : undefined,
      orderBy: [{ city: 'asc' }, { district: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async createOffice(
    name: string,
    regionId: string,
    brokerId?: string | null,
    overridePercent?: number | null,
    actor?: Actor,
  ) {
    const officeName = String(name ?? '').trim();
    if (!officeName) throw new BadRequestException('name is required');
    const normalizedRegionId = String(regionId ?? '').trim();
    if (!normalizedRegionId) throw new BadRequestException('regionId is required');

    const region = await this.prisma.region.findUnique({ where: { id: normalizedRegionId }, select: { id: true } });
    if (!region) throw new NotFoundException('Region not found');

    const normalizedBrokerId = brokerId ? String(brokerId).trim() : null;
    if (normalizedBrokerId) {
      const broker = await this.prisma.user.findUnique({ where: { id: normalizedBrokerId }, select: { id: true } });
      if (!broker) throw new NotFoundException('brokerId user not found');
    }

    if (overridePercent !== undefined && overridePercent !== null) {
      if (!Number.isFinite(overridePercent) || overridePercent < 0 || overridePercent > 100) {
        throw new BadRequestException('overridePercent must be between 0 and 100');
      }
    }

    const office = await this.prisma.office.create({
      data: {
        name: officeName,
        regionId: normalizedRegionId,
        brokerId: normalizedBrokerId,
        overridePercent: overridePercent ?? null,
      },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'ADMIN',
      action: 'OFFICE_CREATED',
      entityType: 'OFFICE' as AuditEntityType,
      entityId: office.id,
      afterJson: {
        name: office.name,
        regionId: office.regionId,
        brokerId: office.brokerId,
        overridePercent: office.overridePercent,
      },
    });
    return office;
  }

  async listOffices(regionId?: string) {
    const rid = String(regionId ?? '').trim();
    return this.prisma.office.findMany({
      where: rid ? { regionId: rid } : undefined,
      orderBy: [{ createdAt: 'desc' }],
      include: {
        region: { select: { id: true, city: true, district: true } },
        broker: { select: { id: true, email: true, role: true } },
      },
    });
  }

  async listOfficeUsers(officeId: string) {
    const oid = String(officeId ?? '').trim();
    if (!oid) throw new BadRequestException('officeId is required');
    const office = await this.prisma.office.findUnique({ where: { id: oid }, select: { id: true } });
    if (!office) throw new NotFoundException('Office not found');

    return this.prisma.user.findMany({
      where: { officeId: oid },
      orderBy: { createdAt: 'desc' },
      select: { id: true, name: true, email: true, role: true, officeId: true },
    });
  }

  async listRegionOffices(regionId: string) {
    const rid = String(regionId ?? '').trim();
    if (!rid) throw new BadRequestException('regionId is required');
    const region = await this.prisma.region.findUnique({ where: { id: rid }, select: { id: true } });
    if (!region) throw new NotFoundException('Region not found');

    return this.prisma.office.findMany({
      where: { regionId: rid },
      orderBy: { createdAt: 'desc' },
      select: { id: true, name: true, brokerId: true, overridePercent: true, regionId: true },
    });
  }

  async assignOfficeBroker(officeId: string, brokerId: string | null) {
    const oid = String(officeId ?? '').trim();
    if (!oid) throw new BadRequestException('officeId is required');

    const office = await this.prisma.office.findUnique({
      where: { id: oid },
      select: { id: true, brokerId: true },
    });
    if (!office) throw new NotFoundException('Office not found');

    const bid = brokerId ? String(brokerId).trim() : null;
    if (bid) {
      const user = await this.prisma.user.findUnique({
        where: { id: bid },
        select: { id: true, role: true },
      });
      if (!user) throw new NotFoundException('brokerId user not found');
      if (user.role !== 'BROKER' && user.role !== 'ADMIN') {
        throw new BadRequestException('brokerId must belong to BROKER or ADMIN');
      }
    }

    return this.prisma.office.update({
      where: { id: oid },
      data: { brokerId: bid },
      select: { id: true, regionId: true, brokerId: true, overridePercent: true },
    });
  }

  async setOfficeOverridePolicy(officeId: string, overridePercent: number | null) {
    const oid = String(officeId ?? '').trim();
    if (!oid) throw new BadRequestException('officeId is required');

    const office = await this.prisma.office.findUnique({
      where: { id: oid },
      select: { id: true },
    });
    if (!office) throw new NotFoundException('Office not found');

    let next: number | null = null;
    if (overridePercent !== null && overridePercent !== undefined) {
      if (!Number.isFinite(overridePercent) || overridePercent < 0 || overridePercent > 100) {
        throw new BadRequestException('overridePercent must be between 0 and 100');
      }
      next = overridePercent;
    }

    return this.prisma.office.update({
      where: { id: oid },
      data: { overridePercent: next },
      select: { id: true, regionId: true, brokerId: true, overridePercent: true },
    });
  }

  async getFranchiseSummary() {
    const [regions, offices] = await Promise.all([
      this.prisma.region.findMany({
        select: { id: true, city: true, district: true },
        orderBy: [{ city: 'asc' }, { district: 'asc' }],
      }),
      this.prisma.office.findMany({
        select: { id: true, name: true, regionId: true, brokerId: true, overridePercent: true },
      }),
    ]);

    const officesByRegion = new Map<string, { total: number; withBroker: number; withOverridePolicy: number }>();
    for (const r of regions) {
      officesByRegion.set(r.id, { total: 0, withBroker: 0, withOverridePolicy: 0 });
    }
    for (const o of offices) {
      const agg = officesByRegion.get(o.regionId) ?? { total: 0, withBroker: 0, withOverridePolicy: 0 };
      agg.total += 1;
      if (o.brokerId) agg.withBroker += 1;
      if (o.overridePercent !== null && o.overridePercent !== undefined) agg.withOverridePolicy += 1;
      officesByRegion.set(o.regionId, agg);
    }

    const regionRows = regions.map((r) => ({
      id: r.id,
      city: r.city,
      district: r.district,
      officeStats: officesByRegion.get(r.id) ?? { total: 0, withBroker: 0, withOverridePolicy: 0 },
    }));

    const totals = {
      regions: regions.length,
      offices: offices.length,
      officesWithBroker: offices.filter((o) => !!o.brokerId).length,
      officesWithOverridePolicy: offices.filter((o) => o.overridePercent !== null && o.overridePercent !== undefined).length,
    };

    return {
      totals,
      regions: regionRows,
      policy: {
        overridePercentRange: '0..100',
        brokerRoleRequired: true,
      },
    };
  }

  async assignUserOffice(userId: string, officeId: string | null, actor?: Actor) {
    const uid = String(userId ?? '').trim();
    if (!uid) throw new BadRequestException('userId is required');
    const existingUser = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { id: true, officeId: true },
    });
    if (!existingUser) throw new NotFoundException('User not found');

    let oid: string | null = officeId ? String(officeId).trim() : null;
    if (oid) {
      const office = await this.prisma.office.findUnique({ where: { id: oid }, select: { id: true } });
      if (!office) throw new NotFoundException('Office not found');
    } else {
      oid = null;
    }

    const updated = await this.prisma.user.update({
      where: { id: uid },
      data: { officeId: oid },
      select: { id: true, officeId: true },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'ADMIN',
      action: 'USER_OFFICE_ASSIGNED',
      entityType: AuditEntityType.USER,
      entityId: uid,
      beforeJson: { officeId: existingUser.officeId ?? null },
      afterJson: { officeId: updated.officeId ?? null },
    });
    return updated;
  }

  async assignLeadRegion(leadId: string, regionId: string | null, actor?: Actor) {
    const lid = String(leadId ?? '').trim();
    if (!lid) throw new BadRequestException('leadId is required');
    const lead = await this.prisma.lead.findUnique({
      where: { id: lid },
      select: { id: true, regionId: true },
    });
    if (!lead) throw new NotFoundException('Lead not found');

    let rid: string | null = regionId ? String(regionId).trim() : null;
    if (rid) {
      const region = await this.prisma.region.findUnique({ where: { id: rid }, select: { id: true } });
      if (!region) throw new NotFoundException('Region not found');
    } else {
      rid = null;
    }

    const updated = await this.prisma.lead.update({
      where: { id: lid },
      data: { regionId: rid },
      select: { id: true, regionId: true },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? 'ADMIN',
      action: 'LEAD_REGION_ASSIGNED',
      entityType: AuditEntityType.LEAD,
      entityId: lid,
      beforeJson: { regionId: lead.regionId ?? null },
      afterJson: { regionId: updated.regionId ?? null },
    });
    return updated;
  }
}
