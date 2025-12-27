import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminLeadsService {
  constructor(private readonly prisma: PrismaService) {}

  async assignLead(leadId: string, userId: string) {
    const lead = await this.prisma.lead.findUnique({ where: { id: leadId } });
    if (!lead) throw new NotFoundException('Lead not found');

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const updated = await this.prisma.lead.update({
      where: { id: leadId },
      data: {
        assignedTo: userId,
        status: 'ASSIGNED',
      },
    });

    return { ok: true, lead: updated };
  }
}

