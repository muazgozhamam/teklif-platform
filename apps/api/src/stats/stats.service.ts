import { Injectable, UnauthorizedException } from '@nestjs/common';
import { DealStatus, LeadStatus, ListingStatus, Role } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StatsCacheService } from './stats-cache.service';

@Injectable()
export class StatsService {
  constructor(private readonly prisma: PrismaService, private readonly cache: StatsCacheService) {}

  async getMe(userId: string, roleRaw: string) {
    if (!userId) {
      throw new UnauthorizedException('Unauthorized');
    }

    const role = (roleRaw || '').toUpperCase() as Role | '';
    const cacheKey = `${role}:${userId}`;
    const cached = this.cache.get<unknown>(cacheKey);
    if (cached) {
      return cached;
    }

    let payload: Record<string, unknown>;

    if (role === Role.HUNTER) {
      const [leadsTotal, leadsNew, leadsReview, leadsApproved, leadsRejected] = await Promise.all([
        this.prisma.lead.count({
          where: {
            sourceUserId: userId,
            status: { in: [LeadStatus.NEW, LeadStatus.REVIEW, LeadStatus.APPROVED, LeadStatus.REJECTED] },
          },
        }),
        this.prisma.lead.count({ where: { sourceUserId: userId, status: LeadStatus.NEW } }),
        this.prisma.lead.count({ where: { sourceUserId: userId, status: LeadStatus.REVIEW } }),
        this.prisma.lead.count({ where: { sourceUserId: userId, status: LeadStatus.APPROVED } }),
        this.prisma.lead.count({ where: { sourceUserId: userId, status: LeadStatus.REJECTED } }),
      ]);

      payload = { role: Role.HUNTER, leadsTotal, leadsNew, leadsReview, leadsApproved, leadsRejected };
      this.cache.set(cacheKey, payload);
      return payload;
    }

    if (role === Role.CONSULTANT) {
      const [dealsMineOpen, dealsReadyForListing, listingsDraft, listingsPublished, listingsSold] = await Promise.all([
        this.prisma.deal.count({
          where: {
            consultantId: userId,
            status: { in: [DealStatus.OPEN, DealStatus.ASSIGNED] },
          },
        }),
        this.prisma.deal.count({
          where: {
            consultantId: userId,
            status: DealStatus.READY_FOR_LISTING,
          },
        }),
        this.prisma.listing.count({ where: { consultantId: userId, status: ListingStatus.DRAFT } }),
        this.prisma.listing.count({ where: { consultantId: userId, status: ListingStatus.PUBLISHED } }),
        this.prisma.listing.count({ where: { consultantId: userId, status: ListingStatus.SOLD } }),
      ]);

      payload = { role: Role.CONSULTANT, dealsMineOpen, dealsReadyForListing, listingsDraft, listingsPublished, listingsSold };
      this.cache.set(cacheKey, payload);
      return payload;
    }

    if (role === Role.BROKER) {
      const [leadsPending, leadsApproved, dealsCreated] = await Promise.all([
        this.prisma.lead.count({ where: { status: { in: [LeadStatus.NEW, LeadStatus.REVIEW] } } }),
        this.prisma.lead.count({ where: { status: LeadStatus.APPROVED } }),
        this.prisma.deal.count(),
      ]);

      payload = { role: Role.BROKER, leadsPending, leadsApproved, dealsCreated };
      this.cache.set(cacheKey, payload);
      return payload;
    }

    if (role === Role.ADMIN) {
      const [usersTotal, leadsTotal, dealsTotal, listingsTotal] = await Promise.all([
        this.prisma.user.count(),
        this.prisma.lead.count(),
        this.prisma.deal.count(),
        this.prisma.listing.count(),
      ]);

      payload = { role: Role.ADMIN, usersTotal, leadsTotal, dealsTotal, listingsTotal };
      this.cache.set(cacheKey, payload);
      return payload;
    }

    payload = { role: Role.USER };
    this.cache.set(cacheKey, payload);
    return payload;
  }
}
