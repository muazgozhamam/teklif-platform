import { Body, Controller, Get, Param, Post, Query, NotFoundException, ConflictException, UseGuards, Req } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditEntityType, LeadStatus } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../common/roles/roles.guard';
import { Roles } from '../common/roles/roles.decorator';
import { AuditService } from '../audit/audit.service';

type LeadRow = {
  id: string;
  category: string;
  status: string;
  title?: string | null;
  city?: string | null;
  district?: string | null;
  neighborhood?: string | null;
  price?: number | null;
  areaM2?: number | null;
  createdAt: string;
  createdBy?: { id: string; name: string; email: string; role: string } | null;
};

function pickAnswer(map: Record<string, string>, keys: string[]): string | null {
  for (const k of keys) {
    const v = map[k];
    if (typeof v === 'string' && v.trim().length) return v.trim();
  }
  return null;
}

function toNumberMaybe(v: string | null): number | null {
  if (!v) return null;
  const cleaned = v.replace(/[^\d.,]/g, '').replace(',', '.');
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

@Controller('broker/leads')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('BROKER', 'ADMIN')
export class BrokerLeadsController {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

  private actorFromReq(req: { user?: { sub?: string; id?: string; role?: string } }) {
    return {
      actorUserId: String(req?.user?.sub ?? req?.user?.id ?? '').trim() || null,
      actorRole: String(req?.user?.role ?? '').trim().toUpperCase() || null,
    };
  }

  @Get('pending')
  async pending(): Promise<LeadRow[]> {
    // "Pending" = broker review queue (NEW + REVIEW)
    const leads = await this.prisma.lead.findMany({
      where: { status: { in: [LeadStatus.NEW, LeadStatus.REVIEW] } },
      orderBy: { createdAt: 'desc' },
      include: {
        answers: { select: { key: true, answer: true } },
      },
    });

    return leads.map((l) => {
      const ans: Record<string, string> = {};
      for (const a of l.answers) ans[a.key] = a.answer;

      const city = pickAnswer(ans, ['city', 'il', 'şehir']);
      const district = pickAnswer(ans, ['district', 'ilce', 'ilçe']);
      const neighborhood = pickAnswer(ans, ['neighborhood', 'mahalle']);

      const price = toNumberMaybe(pickAnswer(ans, ['price', 'fiyat', 'budget', 'butce', 'bütçe']));
      const areaM2 = toNumberMaybe(pickAnswer(ans, ['areaM2', 'm2', 'metrekare', 'alan']));

      // Schema'da category/title yok → türet
      const title =
        (l.initialText || '').trim().slice(0, 80) || '(No title)';

      return {
        id: l.id,
        category: 'GENERAL',
        status: l.status,
        title,
        city,
        district,
        neighborhood,
        price,
        areaM2,
        createdAt: l.createdAt.toISOString(),
        createdBy: null, // Schema'da createdBy ilişkisi yok
      };
    });
  }

  @Get('pending/paged')
  async pendingPaged(
    @Query('page') pageStr?: string,
    @Query('limit') limitStr?: string,
    @Query('take') takeStr?: string,
    @Query('skip') skipStr?: string,
  ): Promise<{ items: (LeadRow & { dealId: string | null })[]; total: number; page: number; limit: number; take: number; skip: number }> {
    const page = Math.max(1, Number(pageStr ?? 1));
    const limit = Math.max(1, Math.min(100, Number(limitStr ?? 20)));
    const take = Math.max(1, Math.min(100, Number(takeStr ?? limit) || limit));
    const skipFromQuery = Math.max(0, Number(skipStr ?? NaN));

    const all = await this.pending();
    const total = all.length;

    const start = Number.isFinite(skipFromQuery) ? skipFromQuery : (page - 1) * limit;
    const items = all.slice(start, start + take);

      // Hydrate dealId for better UX (pending page can show Deal Ready after refresh)
      const leadIds = items.map((x) => x.id);
      const deals = await this.prisma.deal.findMany({
        where: { leadId: { in: leadIds } },
        select: { id: true, leadId: true },
      });
      const dealByLead = new Map<string, string>(deals.map((d) => [d.leadId, d.id]));
      const itemsWithDealId = items.map((it) => ({ ...it, dealId: dealByLead.get(it.id) ?? null }));

      const derivedPage = Math.floor(start / take) + 1;
      return { items: itemsWithDealId, total, page: derivedPage, limit: take, take, skip: start };
  }



  @Post(':id/approve')
  async approve(@Req() req: any, @Param('id') id: string, @Body() _body: { brokerNote?: string }) {
    const lead = await this.prisma.lead.findUnique({ where: { id } });
    if (!lead) throw new NotFoundException('Lead not found');

    if (lead.status !== LeadStatus.NEW && lead.status !== LeadStatus.REVIEW && lead.status !== LeadStatus.APPROVED) {
      throw new ConflictException(`Lead cannot be approved from status=${lead.status}`);
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const updatedLead = await tx.lead.update({
        where: { id },
        data: { status: LeadStatus.APPROVED },
      });

      const existingDeal = await tx.deal.findUnique({ where: { leadId: id } });
      if (existingDeal) {
        return { lead: updatedLead, dealId: existingDeal.id, createdDeal: false };
      }

      const createdDeal = await tx.deal.create({
        data: { leadId: id },
        select: { id: true },
      });
      return { lead: updatedLead, dealId: createdDeal.id, createdDeal: true };
    });

    const actor = this.actorFromReq(req);
    await this.audit.log({
      ...actor,
      action: 'LEAD_STATUS_CHANGED',
      entityType: AuditEntityType.LEAD,
      entityId: id,
      beforeJson: { status: lead.status },
      afterJson: { status: LeadStatus.APPROVED },
      metaJson: { reason: 'BROKER_APPROVE' },
    });
    if (result.createdDeal) {
      await this.audit.log({
        ...actor,
        action: 'DEAL_CREATED',
        entityType: AuditEntityType.DEAL,
        entityId: result.dealId,
        afterJson: { status: 'OPEN' },
        metaJson: { leadId: id, source: 'BROKER_APPROVE' },
      });
    }

    return { ok: true, leadId: id, status: LeadStatus.APPROVED, dealId: result.dealId, createdDeal: result.createdDeal };
  }

  @Post(':id/reject')
  async reject(@Req() req: any, @Param('id') id: string, @Body() _body: { brokerNote?: string }) {
    const lead = await this.prisma.lead.findUnique({ where: { id } });
    if (!lead) throw new NotFoundException('Lead not found');

    const deal = await this.prisma.deal.findUnique({ where: { leadId: id }, select: { id: true } });
    if (deal) {
      throw new ConflictException('Lead already has a deal; reject is blocked');
    }

    await this.prisma.lead.update({
      where: { id },
      data: { status: LeadStatus.REJECTED },
    });
    await this.audit.log({
      ...this.actorFromReq(req),
      action: 'LEAD_STATUS_CHANGED',
      entityType: AuditEntityType.LEAD,
      entityId: id,
      beforeJson: { status: lead.status },
      afterJson: { status: LeadStatus.REJECTED },
      metaJson: { reason: 'BROKER_REJECT' },
    });
    return { ok: true };
  }
  @Post(':id/deal')
  async createDealFromLead(@Req() req: any, @Param('id') id: string) {
    // 1) Lead exists?
    const lead = await this.prisma.lead.findUnique({
      where: { id },
      include: { answers: { select: { key: true, answer: true } } },
    });
    if (!lead) throw new NotFoundException('Lead not found');

    // 2) If deal already exists (leadId unique), return it
    const existing = await this.prisma.deal.findUnique({ where: { leadId: id } });
    if (existing) return { ok: true, dealId: existing.id, created: false };

    // 3) Broker flow rule: only APPROVED leads can be converted
    if (lead.status !== LeadStatus.APPROVED) {
      throw new ConflictException(`Lead is not APPROVED (status=${lead.status})`);
    }

    // Build answer map for snapshot fields
    const ans: Record<string, string> = {};
    for (const a of lead.answers) ans[a.key] = a.answer;

    const city = pickAnswer(ans, ['city', 'il', 'şehir']);
    const district = pickAnswer(ans, ['district', 'ilce', 'ilçe']);
    const type = pickAnswer(ans, ['type', 'emlakType', 'listingType']);
    const rooms = pickAnswer(ans, ['rooms', 'oda', 'odaSayisi', 'oda_sayisi']);

    // Transaction: create deal (status is already APPROVED)
    const createdDeal = await this.prisma.$transaction(async (tx) => {
      const d = await tx.deal.create({
        data: {
          leadId: id,
          city,
          district,
          type,
          rooms,
        },
      });

      return d;
    });

    await this.audit.log({
      ...this.actorFromReq(req),
      action: 'DEAL_CREATED',
      entityType: AuditEntityType.DEAL,
      entityId: createdDeal.id,
      afterJson: { status: 'OPEN' },
      metaJson: { leadId: id, source: 'BROKER_MANUAL_CREATE' },
    });

    return { ok: true, dealId: createdDeal.id, created: true };
  }

}
