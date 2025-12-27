import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OffersService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertLeadAssignedTo(leadId: string, userId: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');
    if (!lead.assignedTo) throw new BadRequestException('Lead is not assigned');
    if (lead.assignedTo !== userId) throw new ForbiddenException('You are not assigned to this lead');
    return lead;
  }

  async createOffer(
    leadId: string,
    meId: string,
    dto: { amount: number; currency?: string; description?: string },
  ) {
    await this.assertLeadAssignedTo(leadId, meId);

    const offer = await this.prisma.offer.create({
      data: {
        leadId,
        consultantId: meId,
        amount: dto.amount,
        currency: dto.currency ?? 'TRY',
        description: dto.description,
        status: 'DRAFT',
      },
    });

    return { ok: true, offer };
  }

  async updateOffer(
    offerId: string,
    meId: string,
    dto: { amount?: number; currency?: string; description?: string },
  ) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.consultantId !== meId) throw new ForbiddenException('Not your offer');
    if (offer.status !== 'DRAFT') throw new BadRequestException('Only DRAFT offers can be updated');

    const updated = await this.prisma.offer.update({
      where: { id: offerId },
      data: {
        amount: dto.amount ?? undefined,
        currency: dto.currency ?? undefined,
        description: dto.description ?? undefined,
      },
    });

    return { ok: true, offer: updated };
  }

  async sendOffer(offerId: string, meId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.consultantId !== meId) throw new ForbiddenException('Not your offer');
    if (offer.status !== 'DRAFT') throw new BadRequestException('Only DRAFT offers can be sent');

    const updated = await this.prisma.$transaction(async (tx) => {
      const sent = await tx.offer.update({
        where: { id: offerId },
        data: { status: 'SENT', sentAt: new Date() },
      });

      await tx.lead.update({
        where: { id: offer.leadId },
        data: { status: 'OFFERED' },
      });

      return sent;
    });

    return { ok: true, offer: updated };
  }

  async cancelOffer(offerId: string, meId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.consultantId !== meId) throw new ForbiddenException('Not your offer');
    if (offer.status === 'ACCEPTED' || offer.status === 'REJECTED') {
      throw new BadRequestException('Decided offers cannot be cancelled');
    }

    const updated = await this.prisma.offer.update({
      where: { id: offerId },
      data: { status: 'CANCELLED' },
    });

    return { ok: true, offer: updated };
  }

  // ADMIN karar
  async acceptOfferAdmin(offerId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.status !== 'SENT') throw new BadRequestException('Only SENT offers can be accepted');

    const updated = await this.prisma.$transaction(async (tx) => {
      const accepted = await tx.offer.update({
        where: { id: offerId },
        data: { status: 'ACCEPTED', decidedAt: new Date() },
      });

      await tx.offer.updateMany({
        where: {
          leadId: offer.leadId,
          id: { not: offerId },
          status: { in: ['DRAFT', 'SENT'] },
        },
        data: { status: 'CANCELLED' },
      });

      await tx.lead.update({
        where: { id: offer.leadId },
        data: { status: 'WON' },
      });

      return accepted;
    });

    return { ok: true, offer: updated };
  }

  async rejectOfferAdmin(offerId: string) {
    const offer = await this.prisma.offer.findUnique({ where: { id: offerId } });
    if (!offer) throw new NotFoundException('Offer not found');
    if (offer.status !== 'SENT') throw new BadRequestException('Only SENT offers can be rejected');

    const updated = await this.prisma.offer.update({
      where: { id: offerId },
      data: { status: 'REJECTED', decidedAt: new Date() },
    });

    return { ok: true, offer: updated };
  }

  async myOffers(meId: string, status?: string) {
    const items = await this.prisma.offer.findMany({
      where: {
        consultantId: meId,
        ...(status ? { status: status as any } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });

    return { ok: true, items };
  }
}
