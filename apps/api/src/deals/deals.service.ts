import { Injectable, ConflictException, NotFoundException, BadRequestException} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MatchingService } from './matching.service';
import { Role, DealStatus } from '@prisma/client';

@Injectable()
export class DealsService {
  constructor(private prisma: PrismaService, private matching: MatchingService) {}

  // ======================
  // READ
  // ======================

  async getById(id: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id },
      include: {
        lead: true,
        consultant: true,
      },
    });

    if (!deal) {
      throw new NotFoundException('Deal not found');
    }

    return deal;
  }

  async getByLeadId(leadId: string) {
    return this.prisma.deal.findFirst({
      where: { leadId },
      include: {
        lead: true,
        consultant: true,
      },
    });
  }

  // ======================
  // CREATE / ENSURE
  // ======================

  async ensureForLead(leadId: string) {
    const existing = await this.prisma.deal.findFirst({
      where: { leadId },
    });

    if (existing) return existing;

    return this.prisma.deal.create({
      data: {
        leadId,
        status: 'OPEN',
      },
    });
  }

  // ======================
  // MATCHING
  // ======================

  async matchDeal(id: string) {
    // Guard: Wizard tamamlanmadan (READY_FOR_MATCH) assign/match yapılmasın
    const deal0 = await this.prisma.deal.findUnique({ where: { id: id } });
    if (!deal0) throw new NotFoundException('Deal not found');
    if (deal0.status !== DealStatus.READY_FOR_MATCHING) {
      throw new BadRequestException(`Deal not ready for match (status=${deal0.status})`);
    }

    const deal = await this.prisma.deal.findUnique({
      where: { id },
    });

    if (!deal) {
      throw new NotFoundException('Deal not found');
    }

    // idempotent
    if (deal.status === 'ASSIGNED') {
      return deal;
    }

    const consultant = await this.prisma.user.findFirst({
      where: { role: Role.CONSULTANT },
      orderBy: { createdAt: 'asc' },
    });

    if (!consultant) {
      throw new ConflictException('No consultant available');
    }

    return this.prisma.deal.update({
      where: { id },
      data: {
        consultantId: consultant.id,
        status: 'ASSIGNED',
      },
    });
  }

  // ======================
  // STATE CONTROL (MINIMAL)
  // ======================

  async ensureStatusOpen(id: string) {
    const deal = await this.prisma.deal.findUnique({ where: { id } });
    if (!deal) return null;

    if (deal.status === 'OPEN') return deal;

    return this.prisma.deal.update({
      where: { id },
      data: { status: 'OPEN' },
    });
  }

  async linkListing(dealId: string, listingId: string, actorUserId: string) {
    const actor = await this.prisma.user.findUnique({ where: { id: actorUserId }, select: { id: true, role: true } });
    if (!actor) throw new NotFoundException('User not found');
    if (actor.role !== Role.CONSULTANT && actor.role !== Role.ADMIN) {
      throw new BadRequestException('Only CONSULTANT/ADMIN can link listing');
    }

    const deal = await this.prisma.deal.findUnique({ where: { id: dealId } });
    if (!deal) throw new NotFoundException('Deal not found');

    const listing = await this.prisma.listing.findUnique({ where: { id: listingId } });
    if (!listing) throw new NotFoundException('Listing not found');

    if (deal.consultantId && actor.role === Role.CONSULTANT && deal.consultantId !== actor.id) {
      throw new BadRequestException('Deal is assigned to another consultant');
    }
    if (actor.role === Role.CONSULTANT && listing.consultantId !== actor.id) {
      throw new BadRequestException('Listing does not belong to this consultant');
    }

    return this.prisma.deal.update({
      where: { id: dealId },
      data: { listingId },
    });
  }

}
