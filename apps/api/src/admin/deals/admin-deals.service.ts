import { Injectable } from '@nestjs/common';
import { Prisma, DealStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

type ListDealsQuery = {
  take?: number;
  skip?: number;
  officeId?: string;
  regionId?: string;
};

@Injectable()
export class AdminDealsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: ListDealsQuery) {
    const take = Math.min(Math.max(Number(query.take ?? 20) || 20, 1), 100);
    const skip = Math.max(Number(query.skip ?? 0) || 0, 0);
    const officeId = String(query.officeId ?? '').trim();
    const regionId = String(query.regionId ?? '').trim();

    const andFilters: Prisma.DealWhereInput[] = [];

    if (officeId) {
      // office scope: consultant assigned to the given office
      andFilters.push({ consultant: { is: { officeId } } });
    }
    if (regionId) {
      // region scope: deal's source lead belongs to region
      andFilters.push({ lead: { regionId } });
    }

    const where: Prisma.DealWhereInput | undefined = andFilters.length ? { AND: andFilters } : undefined;

    const [items, total] = await Promise.all([
      this.prisma.deal.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        select: {
          id: true,
          status: true,
          createdAt: true,
          updatedAt: true,
          city: true,
          district: true,
          type: true,
          rooms: true,
          consultantId: true,
          leadId: true,
          listingId: true,
          consultant: { select: { id: true, email: true, role: true, officeId: true } },
          lead: { select: { id: true, regionId: true, sourceUserId: true, status: true } },
        },
      }),
      this.prisma.deal.count({ where }),
    ]);

    return { items, total, take, skip };
  }
}

