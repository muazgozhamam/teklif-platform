import { Body, Controller, Get, Param, Post, Query, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LeadStatus } from '@prisma/client';

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
export class BrokerLeadsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('pending')
  async pending(): Promise<LeadRow[]> {
    // "Pending" = OPEN leads
    const leads = await this.prisma.lead.findMany({
      where: { status: LeadStatus.OPEN },
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
  ): Promise<{ items: LeadRow[]; total: number; page: number; limit: number }> {
    const page = Math.max(1, Number(pageStr ?? 1));
    const limit = Math.max(1, Math.min(100, Number(limitStr ?? 20)));

    const all = await this.pending();
    const total = all.length;

    const start = (page - 1) * limit;
    const items = all.slice(start, start + limit);

      // Hydrate dealId for better UX (pending page can show Deal Ready after refresh)
      const leadIds = items.map((x) => x.id);
      const deals = await this.prisma.deal.findMany({
        where: { leadId: { in: leadIds } },
        select: { id: true, leadId: true },
      });
      const dealByLead = new Map<string, string>(deals.map((d) => [d.leadId, d.id]));
      const itemsWithDealId = items.map((it) => ({ ...it, dealId: dealByLead.get(it.id) ?? null }));

      return { items: itemsWithDealId, total, page, limit };
  }



  @Post(':id/approve')
  async approve(@Param('id') id: string, @Body() _body: { brokerNote?: string }) {
    await this.prisma.lead.update({
      where: { id },
      data: { status: LeadStatus.COMPLETED },
    });
    return { ok: true };
  }

  @Post(':id/reject')
  async reject(@Param('id') id: string, @Body() _body: { brokerNote?: string }) {
    await this.prisma.lead.update({
      where: { id },
      data: { status: LeadStatus.CANCELLED },
    });
    return { ok: true };
  }
  @Post(':id/deal')
  async createDealFromLead(@Param('id') id: string) {
    // 1) Lead exists?
    const lead = await this.prisma.lead.findUnique({
      where: { id },
      include: { answers: { select: { key: true, answer: true } } },
    });
    if (!lead) throw new NotFoundException('Lead not found');

    // 2) If deal already exists (leadId unique), return it
    const existing = await this.prisma.deal.findUnique({ where: { leadId: id } });
    if (existing) return { ok: true, dealId: existing.id, created: false };

    // 3) Only OPEN leads can be converted into a new deal
    if (lead.status !== LeadStatus.OPEN) {
      throw new ConflictException(`Lead is not OPEN (status=${lead.status})`);
    }

    // Build answer map for snapshot fields
    const ans: Record<string, string> = {};
    for (const a of lead.answers) ans[a.key] = a.answer;

    const city = pickAnswer(ans, ['city', 'il', 'şehir']);
    const district = pickAnswer(ans, ['district', 'ilce', 'ilçe']);
    const type = pickAnswer(ans, ['type', 'emlakType', 'listingType']);
    const rooms = pickAnswer(ans, ['rooms', 'oda', 'odaSayisi', 'oda_sayisi']);

    // Transaction: create deal + mark lead completed so it disappears from pending
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

      await tx.lead.update({
        where: { id },
        data: { status: LeadStatus.COMPLETED },
      });

      return d;
    });

    return { ok: true, dealId: createdDeal.id, created: true };
  }

}
